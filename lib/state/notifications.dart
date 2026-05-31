import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/graphql_config.dart';
import '../api/offline_json_cache_store.dart';
import '../api/queries.dart';
import '../common/accent_color.dart';
import '../common/cold_launch_timing.dart';
import '../models/notification_item.dart';
import '../models/pinned_day_note.dart';
import 'auth.dart';
import 'schedule_filters.dart';

/// Top-level so it can run inside [compute] (an isolate boundary refuses
/// closures and instance methods). Pure JSON→Dart-object map; mirrors the
/// 1.2.10 raspisanie parser pattern. Moves the cold-start parse cost off
/// the main isolate.
List<NotificationItem> parseNotificationItems(List<Map<String, dynamic>> raw) {
  return raw.map(NotificationItem.fromJson).toList(growable: false);
}

/// Top-level parser for [pinnedNotesInRange] / [pinnedNotesForDate]. Returns
/// the raw [PinnedDayNote] list — accent colors are still resolved on the
/// main isolate (cheap, and [Color] doesn't cross the isolate boundary).
List<PinnedDayNote> parsePinnedDayNotes(List<Map<String, dynamic>> raw) {
  return raw.map(PinnedDayNote.fromJson).toList(growable: false);
}

/// Heavy-stage yield for cold start. After a compute() returns the parsed
/// list, the main isolate still has to flip Riverpod state and trigger the
/// next frame. Adding a post-compute zero-delay yields control back to the
/// scheduler so input dispatch and rendering aren't starved during the
/// transition between two heavy stages.
Future<void> _yieldToEventLoop() => Future<void>.delayed(Duration.zero);

const _notificationsListCacheKey = 'notifications:list:all';
const _notificationsUnreadCacheKey = 'notifications:list:unread';
const _appSettingsCacheKey = 'appSettings';
const _notificationsForDatesCachePrefix = 'notificationsForDates:';
const _pinnedNotesRangeCachePrefix = 'pinnedNotesInRange:';
const _pinnedNotesDateCachePrefix = 'pinnedNotesForDate:';

String _notificationsForDatesCacheKey(DateTime from, DateTime to) =>
    '$_notificationsForDatesCachePrefix${_isoDate(from)}:${_isoDate(to)}';

String _pinnedNotesRangeCacheKey(DateTime from, DateTime to) =>
    '$_pinnedNotesRangeCachePrefix${_isoDate(from)}:${_isoDate(to)}';

String _pinnedNotesDateCacheKey(DateTime date) =>
    '$_pinnedNotesDateCachePrefix${_isoDate(date)}';

List<Map<String, dynamic>> _rawRows(QueryResult result, String field) {
  final list = (result.data?[field] as List?) ?? const [];
  return list
      .cast<Map>()
      .map((row) => Map<String, dynamic>.from(row.cast<dynamic, dynamic>()))
      .toList(growable: false);
}

const _cacheFirstRefreshTtl = Duration(minutes: 3);
final _cacheFirstRefreshLastAt = <String, DateTime>{};

bool _cacheFirstRefreshDue(String key) {
  final last = _cacheFirstRefreshLastAt[key];
  if (last == null) return true;
  return DateTime.now().difference(last) > _cacheFirstRefreshTtl;
}

void _refreshProviderInBackground(
  Ref ref,
  String key,
  Future<void> Function() refresh, {
  void Function()? afterRefresh,
}) {
  if (!_cacheFirstRefreshDue(key)) return;
  _cacheFirstRefreshLastAt[key] = DateTime.now();
  var disposed = false;
  ref.onDispose(() => disposed = true);
  unawaited(() async {
    try {
      await refresh();
      if (disposed) return;
      afterRefresh?.call();
      ref.invalidateSelf();
    } catch (_) {}
  }());
}

Future<List<NotificationItem>> _parseNotifications(
  List<Map<String, dynamic>> rawMaps, {
  required String timingName,
}) async {
  if (rawMaps.isEmpty) return const <NotificationItem>[];
  logTiming('compute.$timingName.spawn');
  final parsed = await compute(parseNotificationItems, rawMaps);
  logTiming('compute.$timingName.return');
  await _yieldToEventLoop();
  return parsed;
}

Future<List<PinnedDayNote>> _parsePinnedNotes(
  List<Map<String, dynamic>> rawMaps, {
  required String timingName,
}) async {
  if (rawMaps.isEmpty) return const <PinnedDayNote>[];
  logTiming('compute.$timingName.spawn');
  final parsed = await compute(parsePinnedDayNotes, rawMaps);
  logTiming('compute.$timingName.return');
  await _yieldToEventLoop();
  return parsed;
}

Future<void> _writeNotificationsCaches(
  OfflineJsonCacheStore cache,
  List<Map<String, dynamic>> rows,
) async {
  await cache.writeRows(_notificationsListCacheKey, rows);
  await cache.writeRows(
    _notificationsUnreadCacheKey,
    [
      for (final row in rows)
        if (row['isRead'] != true) row,
    ],
  );
}

/// Stagger gap for cold-start cascade serialization (Item 2c). Notifications
/// + unreadCount fire ~200ms after Auth resolves so the schedule fetch+parse
/// owns the first cold-launch window. Cheap on the warm path because the
/// providers keep their results alive between rebuilds.
const _kNotificationsStartupStagger = Duration(milliseconds: 200);

/// Stagger gap for the "less critical" data — pinned notes + appSettings.
/// Lands well after the schedule first frame and the notification badge.
const _kPinnedNotesStartupStagger = Duration(milliseconds: 400);

/// Push-driven unread-count notifier. Replaces the 1.2.8-and-earlier
/// `Stream.periodic(30s)` poller — the periodic background fetch was the
/// root cause of the post-resume "backend unreachable" flash, since it
/// could fail mid-pause and surface its error the moment the app came
/// back to the foreground.
///
/// Lifecycle of the count:
/// - `build()` issues ONE GraphQL query for the authoritative count on
///   first watch and on every auth-state transition (login/logout).
/// - Foreground FCM `onMessage` increments the counter by 1
///   (see `_handleForeground` in `lib/push/push_manager.dart`). The
///   payload's `kind`/`data` shape isn't reliably distinguishable, so we
///   bump unconditionally on any incoming push and let the resume
///   safety-net reconcile.
/// - `markRead` mutation success decrements by 1 (clamped at 0).
/// - `markAllRead` / `delete` invalidate this provider so build() re-runs.
/// - On resume, the lifecycle observer in `_MyAppState` calls
///   `refreshForeground()` to catch pushes that landed while we were
///   backgrounded and the foreground onMessage hook didn't fire.
/// Delay before the very first unread-count query fires after a fresh
/// `build()`. The badge is a non-critical UI element — making it wait half
/// a second yields the cold-launch window to the schedule fetch+parse so
/// the user sees lessons sooner. Subsequent rebuilds (auth epoch flips,
/// invalidations) honor the same delay; the cost is negligible vs. the
/// gain on the cold path.
///
/// Sits right at the 1.2.11 cold-start cascade T+200ms slot defined in
/// [_kNotificationsStartupStagger] (kept at 500ms here so the badge still
/// queues AFTER the notifications list query — the list-watching screen
/// is more user-visible).
const _kUnreadCountStartupDelay = Duration(milliseconds: 500);

class UnreadCount extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final authed =
        ref.watch(authProvider).asData?.value.isAuthenticated ?? false;
    if (!authed) return 0;
    // Re-fetch on auth epoch bumps so the new token's notifications land.
    ref.watch(authEpochProvider);
    final cache = ref.read(offlineJsonCacheStoreProvider);
    final cached = await _cachedUnreadCount(cache);
    if (cached != null) {
      _refreshUnreadCountInBackground(cache);
      return cached;
    }
    // Yield the cold-launch window. Local count display starts at 0 until
    // the first fetch resolves — fine, the badge is non-critical and the
    // FCM push hook still increments it in real time.
    await Future<void>.delayed(_kUnreadCountStartupDelay);
    return _fetchCount();
  }

  Future<int?> _cachedUnreadCount(OfflineJsonCacheStore cache) async {
    final cached = await cache.readRows(_notificationsUnreadCacheKey) ??
        await cache.readRows(_notificationsListCacheKey);
    if (cached == null) return null;
    return cached.where((row) => row['isRead'] != true).length;
  }

  void _refreshUnreadCountInBackground(OfflineJsonCacheStore cache) {
    if (!_cacheFirstRefreshDue(_notificationsUnreadCacheKey)) return;
    _cacheFirstRefreshLastAt[_notificationsUnreadCacheKey] = DateTime.now();
    unawaited(() async {
      try {
        final count = await _fetchCountFresh(cache);
        state = AsyncValue.data(count);
      } catch (_) {}
    }());
  }

  Future<int> _fetchCountFresh(OfflineJsonCacheStore cache) async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.query(QueryOptions(
      document: gql(notificationsQuery),
      variables: const {'unreadOnly': true},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final rows = _rawRows(r, 'notifications');
    await cache.writeRows(_notificationsUnreadCacheKey, rows);
    return rows.length;
  }

  Future<int> _fetchCount() async {
    try {
      final cache = ref.read(offlineJsonCacheStoreProvider);
      // build() is called from a non-foreground-guaranteed context (a
      // first watch can land during resume work), so DO NOT route a
      // failure through `handleAuthOpFailure` here — that path is what
      // we just fixed in part 1. Return the prior value (or 0) on error
      // and let the next mutation/refresh reconcile.
      return await _fetchCountFresh(cache);
    } catch (_) {
      final cached =
          await _cachedUnreadCount(ref.read(offlineJsonCacheStoreProvider));
      return cached ?? state.asData?.value ?? 0;
    }
  }

  /// Increment for a foreground push. Must NOT call into
  /// `handleAuthOpFailure` — the FCM dispatch can land during a
  /// not-yet-foreground window and we don't want to re-introduce the
  /// flash. Pure local state mutation.
  void incrementForPush() {
    final cur = state.asData?.value ?? 0;
    state = AsyncValue.data(cur + 1);
  }

  /// Optimistic decrement on successful markRead. Clamps at 0 so a stale
  /// or duplicate mark can't push the badge into negative territory.
  void decrement() {
    final cur = state.asData?.value ?? 0;
    final next = cur - 1;
    state = AsyncValue.data(next < 0 ? 0 : next);
  }

  void clear() {
    state = const AsyncValue.data(0);
  }

  /// Resume safety-net: re-fetches the authoritative count from the server
  /// to catch pushes that arrived while the app was backgrounded. Called
  /// only from the lifecycle observer (foreground-by-definition), so it's
  /// safe to route a transport failure through the existing handler.
  Future<void> refreshForeground() async {
    final authed =
        ref.read(authProvider).asData?.value.isAuthenticated ?? false;
    if (!authed) {
      state = const AsyncValue.data(0);
      return;
    }
    try {
      final cache = ref.read(offlineJsonCacheStoreProvider);
      state = AsyncValue.data(await _fetchCountFresh(cache));
    } on OperationException catch (e) {
      final cached =
          await _cachedUnreadCount(ref.read(offlineJsonCacheStoreProvider));
      if (cached != null) {
        state = AsyncValue.data(cached);
        return;
      }
      await ref.read(authProvider.notifier).handleAuthOpFailure(e);
    } catch (_) {}
  }
}

final unreadCountProvider =
    AsyncNotifierProvider<UnreadCount, int>(UnreadCount.new);

class NotificationsList extends AsyncNotifier<List<NotificationItem>> {
  bool _markAllReadInFlight = false;

  @override
  Future<List<NotificationItem>> build() async {
    final authed =
        ref.watch(authProvider).asData?.value.isAuthenticated ?? false;
    if (!authed) return const <NotificationItem>[];
    ref.watch(authEpochProvider);
    final cache = ref.read(offlineJsonCacheStoreProvider);
    final cached = await cache.readRows(_notificationsListCacheKey);
    if (cached != null) {
      _refreshProviderInBackground(
        ref,
        _notificationsListCacheKey,
        () async => _fetchFreshRows(cache),
        afterRefresh: () => ref.invalidate(unreadCountProvider),
      );
      return _parseNotifications(cached, timingName: 'notifications');
    }
    // Cold-start cascade serialization (Item 2c): yield 200ms so the
    // schedule fetch+parse owns the first launch window. On the warm path
    // (filter switch / invalidation) this is imperceptible.
    await Future<void>.delayed(_kNotificationsStartupStagger);
    logTiming('query.notifications.start');
    try {
      final rawMaps = await _fetchFreshRows(cache);
      logTiming('query.notifications.end');
      return _parseNotifications(rawMaps, timingName: 'notifications');
    } on OperationException catch (e) {
      logTiming('query.notifications.end');
      final fallback = await cache.readRows(_notificationsListCacheKey);
      if (fallback != null) {
        return _parseNotifications(fallback, timingName: 'notifications');
      }
      await ref.read(authProvider.notifier).handleAuthOpFailure(e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFreshRows(
    OfflineJsonCacheStore cache,
  ) async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.query(QueryOptions(
      document: gql(notificationsQuery),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final rawMaps = _rawRows(r, 'notifications');
    await _writeNotificationsCaches(cache, rawMaps);
    return rawMaps;
  }

  Future<void> markRead(int id) async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(markNotificationReadMutation),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    unawaited(ref
        .read(offlineJsonCacheStoreProvider)
        .remove(_notificationsListCacheKey));
    unawaited(ref
        .read(offlineJsonCacheStoreProvider)
        .remove(_notificationsUnreadCacheKey));
    // Optimistic local update so the list stripe disappears instantly.
    // Capture the prior unread state so we don't double-decrement when a
    // caller marks an already-read item.
    final current = state.asData?.value;
    bool wasUnread = false;
    if (current != null) {
      for (final n in current) {
        if (n.id == id) {
          wasUnread = !n.isRead;
          break;
        }
      }
      state = AsyncValue.data([
        for (final n in current)
          if (n.id == id) n.copyWith(isRead: true) else n,
      ]);
    }
    if (wasUnread) {
      ref.read(unreadCountProvider.notifier).decrement();
    }
  }

  Future<void> markAllRead() async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(markAllNotificationsReadMutation),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final cache = ref.read(offlineJsonCacheStoreProvider);
    unawaited(cache.remove(_notificationsListCacheKey));
    unawaited(cache.remove(_notificationsUnreadCacheKey));
    ref.invalidateSelf();
    ref.read(unreadCountProvider.notifier).clear();
  }

  /// Optimistic mark-all-read used when the tab is first opened.
  /// Fires the server mutation even when the local list is empty/stale, then
  /// uses whatever list state exists for immediate UI cleanup.
  Future<void> autoMarkAllRead() async {
    final current = state.asData?.value;
    if (current != null && current.any((n) => !n.isRead)) {
      state = AsyncValue.data([
        for (final n in current) n.copyWith(isRead: true),
      ]);
    }
    ref.read(unreadCountProvider.notifier).clear();
    if (_markAllReadInFlight) return;
    _markAllReadInFlight = true;
    try {
      final client = ref.read(graphqlClientProvider);
      final r = await client.mutate(MutationOptions(
        document: gql(markAllNotificationsReadMutation),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      final cache = ref.read(offlineJsonCacheStoreProvider);
      unawaited(cache.remove(_notificationsListCacheKey));
      unawaited(cache.remove(_notificationsUnreadCacheKey));
      if (r.hasException) {
        ref.invalidate(unreadCountProvider);
      }
    } catch (_) {
      ref.invalidate(unreadCountProvider);
    } finally {
      _markAllReadInFlight = false;
    }
  }

  Future<void> delete(int id) async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(deleteNotificationMutation),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final cache = ref.read(offlineJsonCacheStoreProvider);
    unawaited(cache.remove(_notificationsListCacheKey));
    unawaited(cache.remove(_notificationsUnreadCacheKey));
    unawaited(cache.removeByKeyPrefix(_notificationsForDatesCachePrefix));
    unawaited(cache.removeByKeyPrefix(_pinnedNotesRangeCachePrefix));
    unawaited(cache.removeByKeyPrefix(_pinnedNotesDateCachePrefix));
    ref.invalidateSelf();
    ref.invalidate(unreadCountProvider);
  }

  Future<NotificationItem> send({
    required NotificationScope scope,
    required List<int> groupIds,
    required String body,
    DateTime? linkedDate,
  }) async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(sendNotificationMutation),
      variables: {
        'scope': scopeToString(scope),
        'groupIds': groupIds.isEmpty ? null : groupIds,
        'body': body,
        'linkedDate': linkedDate == null ? null : _isoDate(linkedDate),
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final cache = ref.read(offlineJsonCacheStoreProvider);
    unawaited(cache.remove(_notificationsListCacheKey));
    unawaited(cache.remove(_notificationsUnreadCacheKey));
    unawaited(cache.removeByKeyPrefix(_notificationsForDatesCachePrefix));
    unawaited(cache.removeByKeyPrefix(_pinnedNotesRangeCachePrefix));
    unawaited(cache.removeByKeyPrefix(_pinnedNotesDateCachePrefix));
    final created = NotificationItem.fromJson(
      r.data!['sendNotification'] as Map<String, dynamic>,
    );
    ref.invalidateSelf();
    return created;
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsList, List<NotificationItem>>(
  NotificationsList.new,
);

/// Dates (truncated to day, local TZ) that have a date-linked notification
/// within the displayed month. Feeds the red outline on the calendar grid.
final notificationsForMonthProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
  ref.keepAlive();
  final authed = ref.watch(authProvider).asData?.value.isAuthenticated ?? false;
  if (!authed) return const <DateTime>{};
  ref.watch(authEpochProvider);
  // Refetch when the feed is invalidated — e.g. after send/delete.
  ref.watch(notificationsProvider);
  final client = ref.read(graphqlClientProvider);
  final cache = ref.read(offlineJsonCacheStoreProvider);
  final from = gridStartFor(month);
  final to = gridEndFor(month);
  final cacheKey = _notificationsForDatesCacheKey(from, to);
  final cached = await cache.readRows(cacheKey);
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      cacheKey,
      () async => _fetchNotificationsForDatesFresh(
        client: client,
        cache: cache,
        cacheKey: cacheKey,
        from: from,
        to: to,
      ),
    );
    return _linkedDateSet(
        await _parseNotifications(cached, timingName: 'notifsForDates'));
  }
  // Cold-start cascade gap (Item 2c): pinned notes + notification dots
  // come AFTER the schedule + notifications list have had their parse window.
  await Future<void>.delayed(_kPinnedNotesStartupStagger);
  logTiming('query.notifsForDates.start');
  try {
    final rawMaps = await _fetchNotificationsForDatesFresh(
      client: client,
      cache: cache,
      cacheKey: cacheKey,
      from: from,
      to: to,
    );
    logTiming('query.notifsForDates.end');
    return _linkedDateSet(
        await _parseNotifications(rawMaps, timingName: 'notifsForDates'));
  } on OperationException catch (e) {
    logTiming('query.notifsForDates.end');
    final fallback = await cache.readRows(cacheKey);
    if (fallback != null) {
      return _linkedDateSet(
          await _parseNotifications(fallback, timingName: 'notifsForDates'));
    }
    await ref.read(authProvider.notifier).handleAuthOpFailure(e);
    return const <DateTime>{};
  }
});

/// Convenience: refresh the month outline when the user pages months.
final displayedMonthNotificationsProvider =
    Provider<AsyncValue<Set<DateTime>>>((ref) {
  final month = ref.watch(displayedMonthProvider);
  return ref.watch(notificationsForMonthProvider(month));
});

/// Read-only list of pinned notes visible to the caller on `date`.
/// Sorted oldest-first by the server. Empty for guests.
final pinnedNotesProvider =
    FutureProvider.family<List<PinnedDayNote>, DateTime>((ref, date) async {
  final authed = ref.watch(authProvider).asData?.value.isAuthenticated ?? false;
  if (!authed) return const <PinnedDayNote>[];
  ref.watch(authEpochProvider);
  // Refetch when the notifications feed changes — e.g. after send/delete.
  ref.watch(notificationsProvider);
  final client = ref.read(graphqlClientProvider);
  final cache = ref.read(offlineJsonCacheStoreProvider);
  final d = DateTime(date.year, date.month, date.day);
  final cacheKey = _pinnedNotesDateCacheKey(d);
  final cached = await cache.readRows(cacheKey);
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      cacheKey,
      () async => _fetchPinnedNotesForDateFresh(
        client: client,
        cache: cache,
        cacheKey: cacheKey,
        date: d,
      ),
    );
    return _parsePinnedNotes(cached, timingName: 'pinnedNotesForDate');
  }
  try {
    final rawMaps = await _fetchPinnedNotesForDateFresh(
      client: client,
      cache: cache,
      cacheKey: cacheKey,
      date: d,
    );
    return _parsePinnedNotes(rawMaps, timingName: 'pinnedNotesForDate');
  } on OperationException catch (e) {
    final fallback = await cache.readRows(cacheKey);
    if (fallback != null) {
      return _parsePinnedNotes(fallback, timingName: 'pinnedNotesForDate');
    }
    await ref.read(authProvider.notifier).handleAuthOpFailure(e);
    return const <PinnedDayNote>[];
  }
});

/// Dates (local-TZ, truncated) that have at least one pinned note visible to
/// the caller, covering the 42-day calendar grid for `month`, mapped to the
/// list of sender accent colors for that date. Empty list under a date key is
/// impossible (the date simply won't appear).
final pinnedNotesForMonthProvider =
    FutureProvider.family<Map<DateTime, List<Color>>, DateTime>(
        (ref, month) async {
  ref.keepAlive();
  final authed = ref.watch(authProvider).asData?.value.isAuthenticated ?? false;
  if (!authed) return const <DateTime, List<Color>>{};
  ref.watch(authEpochProvider);
  ref.watch(notificationsProvider);
  final client = ref.read(graphqlClientProvider);
  final cache = ref.read(offlineJsonCacheStoreProvider);
  final from = gridStartFor(month);
  final to = gridEndFor(month);
  final cacheKey = _pinnedNotesRangeCacheKey(from, to);
  final cached = await cache.readRows(cacheKey);
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      cacheKey,
      () async => _fetchPinnedNotesInRangeFresh(
        client: client,
        cache: cache,
        cacheKey: cacheKey,
        from: from,
        to: to,
      ),
    );
    return _pinnedNotesByDate(
        await _parsePinnedNotes(cached, timingName: 'pinnedNotes'));
  }
  // Stagger after pinned-notes / notification-dots in the cold-start
  // cascade. Calendar overlays are visible BUT non-blocking — yielding the
  // cold launch window to the schedule fetch is the right trade-off.
  await Future<void>.delayed(_kPinnedNotesStartupStagger);
  logTiming('query.pinnedNotes.start');
  try {
    final rawMaps = await _fetchPinnedNotesInRangeFresh(
      client: client,
      cache: cache,
      cacheKey: cacheKey,
      from: from,
      to: to,
    );
    logTiming('query.pinnedNotes.end');
    return _pinnedNotesByDate(
        await _parsePinnedNotes(rawMaps, timingName: 'pinnedNotes'));
  } on OperationException catch (e) {
    logTiming('query.pinnedNotes.end');
    final fallback = await cache.readRows(cacheKey);
    if (fallback != null) {
      return _pinnedNotesByDate(
          await _parsePinnedNotes(fallback, timingName: 'pinnedNotes'));
    }
    await ref.read(authProvider.notifier).handleAuthOpFailure(e);
    return const <DateTime, List<Color>>{};
  }
});

final displayedMonthPinnedProvider =
    Provider<AsyncValue<Map<DateTime, List<Color>>>>((ref) {
  final month = ref.watch(displayedMonthProvider);
  return ref.watch(pinnedNotesForMonthProvider(month));
});

/// App-wide settings readable by any authenticated user.
/// Kept alive so the compose sheet doesn't re-fetch on every open.
final appSettingsProvider =
    FutureProvider.autoDispose<({bool teachersCanBroadcastGlobally})>(
        (ref) async {
  final authed = ref.watch(authProvider).asData?.value.isAuthenticated ?? false;
  if (!authed) return (teachersCanBroadcastGlobally: false);
  ref.watch(authEpochProvider);
  final cache = ref.read(offlineJsonCacheStoreProvider);
  final client = ref.read(graphqlClientProvider);
  final cached = await cache.readObject(_appSettingsCacheKey);
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      _appSettingsCacheKey,
      () async => _fetchAppSettingsFresh(client: client, cache: cache),
    );
    return (
      teachersCanBroadcastGlobally:
          (cached['teachersCanBroadcastGlobally'] as bool?) ?? false,
    );
  }
  // Settings is a single-row scalar payload — no compute() benefit (Item 2a
  // explicitly skips this). Keep the cold-start stagger so the autoDispose
  // re-fetch doesn't pile onto the schedule first frame.
  await Future<void>.delayed(_kPinnedNotesStartupStagger);
  logTiming('query.appSettings.start');
  try {
    final data = await _fetchAppSettingsFresh(client: client, cache: cache);
    logTiming('query.appSettings.end');
    return (
      teachersCanBroadcastGlobally:
          (data['teachersCanBroadcastGlobally'] as bool?) ?? false,
    );
  } on OperationException {
    logTiming('query.appSettings.end');
    final fallback = await cache.readObject(_appSettingsCacheKey);
    return (
      teachersCanBroadcastGlobally:
          (fallback?['teachersCanBroadcastGlobally'] as bool?) ?? false,
    );
  }
});

const _defaultAccent = Color(0xFFEF4444);

Future<List<Map<String, dynamic>>> _fetchNotificationsForDatesFresh({
  required GraphQLClient client,
  required OfflineJsonCacheStore cache,
  required String cacheKey,
  required DateTime from,
  required DateTime to,
}) async {
  final r = await client.query(QueryOptions(
    document: gql(notificationsForDatesQuery),
    variables: {
      'from': _isoDate(from),
      'to': _isoDate(to),
    },
    fetchPolicy: FetchPolicy.networkOnly,
  ));
  if (r.hasException) throw r.exception!;
  final rows = _rawRows(r, 'notificationsForDates');
  await cache.writeRows(cacheKey, rows);
  return rows;
}

Future<List<Map<String, dynamic>>> _fetchPinnedNotesForDateFresh({
  required GraphQLClient client,
  required OfflineJsonCacheStore cache,
  required String cacheKey,
  required DateTime date,
}) async {
  final r = await client.query(QueryOptions(
    document: gql(pinnedNotesForDateQuery),
    variables: {'date': _isoDate(date)},
    fetchPolicy: FetchPolicy.networkOnly,
  ));
  if (r.hasException) throw r.exception!;
  final rows = _rawRows(r, 'pinnedNotesForDate');
  await cache.writeRows(cacheKey, rows);
  return rows;
}

Future<List<Map<String, dynamic>>> _fetchPinnedNotesInRangeFresh({
  required GraphQLClient client,
  required OfflineJsonCacheStore cache,
  required String cacheKey,
  required DateTime from,
  required DateTime to,
}) async {
  final r = await client.query(QueryOptions(
    document: gql(pinnedNotesInRangeQuery),
    variables: {
      'from': _isoDate(from),
      'to': _isoDate(to),
    },
    fetchPolicy: FetchPolicy.networkOnly,
  ));
  if (r.hasException) throw r.exception!;
  final rows = _rawRows(r, 'pinnedNotesInRange');
  await cache.writeRows(cacheKey, rows);
  return rows;
}

Future<Map<String, dynamic>> _fetchAppSettingsFresh({
  required GraphQLClient client,
  required OfflineJsonCacheStore cache,
}) async {
  final r = await client.query(QueryOptions(
    document: gql(appSettingsQuery),
    fetchPolicy: FetchPolicy.networkOnly,
  ));
  if (r.hasException) throw r.exception!;
  final data = r.data?['appSettings'];
  if (data is! Map) return const <String, dynamic>{};
  final map = Map<String, dynamic>.from(data.cast<dynamic, dynamic>());
  await cache.writeObject(_appSettingsCacheKey, map);
  return map;
}

Set<DateTime> _linkedDateSet(Iterable<NotificationItem> items) {
  final out = <DateTime>{};
  for (final item in items) {
    final d = item.linkedDate;
    if (d != null) out.add(DateTime(d.year, d.month, d.day));
  }
  return out;
}

Map<DateTime, List<Color>> _pinnedNotesByDate(Iterable<PinnedDayNote> pins) {
  final out = <DateTime, List<Color>>{};
  for (final pin in pins) {
    final key = DateTime(
      pin.linkedDate.year,
      pin.linkedDate.month,
      pin.linkedDate.day,
    );
    final c = parseHexColor(pin.sender.accentColor) ?? _defaultAccent;
    out.putIfAbsent(key, () => <Color>[]).add(c);
  }
  return out;
}

String _isoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
