import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../common/cold_launch_timing.dart';
import '../common/filter_sort.dart';
import '../common/week_math.dart' as week_math;
import '../models/day_note.dart';
import '../models/queued_note_op.dart';
import '../models/raspisanie.dart';
import '../state/note_queue.dart';
import '../state/notifications.dart'
    show notificationsForMonthProvider, pinnedNotesForMonthProvider;
import '../state/schedule_filters.dart';
import 'graphql_config.dart';
import 'note_storage.dart';
import 'offline_json_cache_store.dart';
import 'queries.dart';
import 'schedule_cache_store.dart';

/// Top-level so it can run inside [compute] (an isolate boundary refuses
/// closures and instance methods). Pure JSON→Dart-object map; any failure
/// here surfaces as a parse exception in the calling [Future].
List<RaspisanieEntry> parseRaspisanieList(List<Map<String, dynamic>> raw) {
  return raw.map(RaspisanieEntry.fromJson).toList(growable: false);
}

/// Drops literal duplicates from [entries], keeping the first occurrence of
/// each (date, slot, subgroup, classroom, group, teacher, subject) tuple.
///
/// Necessary when multiple [monthRaspisanieByMonthProvider] caches are merged
/// (1.3.0 day-strip and week-list views). `gridStartFor`/`gridEndFor` returns
/// 42-day windows that overlap between adjacent months — fetching ±2 months
/// (day-strip) or two month-boundary-straddling months (week-list) means the
/// same DB row arrives via two providers and would otherwise render twice.
///
/// Subgroup is part of the key so a real lab split (the same lecture taught
/// to two subgroups in parallel by different teachers / different rooms)
/// stays as separate cards. The home-widget data path applies a tighter fold
/// (no subgroup) to collapse parallel subgroups into one row, which is the
/// right call there but would lose information here on the schedule screen.
List<RaspisanieEntry> dedupRaspisanieEntries(
    Iterable<RaspisanieEntry> entries) {
  final seen = <String>{};
  final out = <RaspisanieEntry>[];
  for (final e in entries) {
    final y = e.date.year.toString().padLeft(4, '0');
    final m = e.date.month.toString().padLeft(2, '0');
    final d = e.date.day.toString().padLeft(2, '0');
    final key = '$y-$m-$d|${e.subjectNumber}|${e.subgroup ?? -1}'
        '|${e.classroom}|${e.group.id}|${e.teacher.id}|${e.subject.id}';
    if (seen.add(key)) out.add(e);
  }
  return out;
}

class RaspisanieRepository {
  RaspisanieRepository(
    this._client, {
    ScheduleCacheStore? scheduleCache,
    OfflineJsonCacheStore? offlineCache,
  })  : _scheduleCache = scheduleCache ?? const DisabledScheduleCacheStore(),
        _offlineCache = offlineCache ?? const DisabledOfflineJsonCacheStore();

  final GraphQLClient _client;
  final ScheduleCacheStore _scheduleCache;
  final OfflineJsonCacheStore _offlineCache;

  QueryOptions _raspisanieOptions({
    List<int>? groupIds,
    List<int>? teacherIds,
    List<String>? classrooms,
    DateTime? from,
    DateTime? to,
    required FetchPolicy fetchPolicy,
  }) =>
      QueryOptions(
        document: gql(raspisanieQuery),
        variables: {
          'groups': groupIds,
          'teachers': teacherIds,
          'classrooms': classrooms,
          'from': _isoDate(from),
          'to': _isoDate(to),
        },
        fetchPolicy: fetchPolicy,
      );

  Future<List<RaspisanieEntry>> _parseRaspisanieRows(
      List<Map<String, dynamic>> rawMaps) async {
    if (rawMaps.isEmpty) return const <RaspisanieEntry>[];
    // Parse off the main isolate. The 1.2.10 snappy-resume work measured
    // this loop at 500–1000ms on a 540-entry month — long enough to block
    // the first frame after a cold launch or filter change.
    logTiming('compute.raspisanie.spawn');
    final parsed = await compute(parseRaspisanieList, rawMaps);
    logTiming('compute.raspisanie.return');
    return parsed;
  }

  List<Map<String, dynamic>> _raspisanieRawRows(QueryResult result) {
    if (result.hasException) throw result.exception!;
    final list = (result.data?['raspisanie'] as List?) ?? const [];
    return list
        .cast<Map>()
        .map((row) => Map<String, dynamic>.from(row.cast<dynamic, dynamic>()))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _rawRefRows(QueryResult result, String field) {
    final list = (result.data?[field] as List?) ?? const [];
    return list
        .cast<Map>()
        .map((row) => Map<String, dynamic>.from(row.cast<dynamic, dynamic>()))
        .toList(growable: false);
  }

  Future<List<RaspisanieEntry>> fetch({
    List<int>? groupIds,
    List<int>? teacherIds,
    List<String>? classrooms,
    DateTime? from,
    DateTime? to,
    FetchPolicy fetchPolicy = FetchPolicy.networkOnly,
  }) async {
    logTiming('query.raspisanie.start');
    final key = _scheduleCacheKey(
      groupIds: groupIds,
      teacherIds: teacherIds,
      classrooms: classrooms,
      from: from,
      to: to,
    );
    try {
      if (fetchPolicy == FetchPolicy.cacheOnly) {
        final cached = await _scheduleCache.read(key);
        return cached == null
            ? const <RaspisanieEntry>[]
            : await _parseRaspisanieRows(cached);
      }

      // Do not use GraphQL cacheAndNetwork for schedule reads. graphql_flutter
      // resolves client.query() with the stale cache hit and writes the
      // network result later, which made refreshed schedule rows appear only
      // after cold restart. Network-first is explicit; offline fallback reads
      // our small bounded schedule cache instead of the old global HiveStore.
      final result = await _client.query(_raspisanieOptions(
        groupIds: groupIds,
        teacherIds: teacherIds,
        classrooms: classrooms,
        from: from,
        to: to,
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      final rawMaps = _raspisanieRawRows(result);
      await _scheduleCache.write(key, rawMaps);
      return _parseRaspisanieRows(rawMaps);
    } on OperationException {
      final cached = await _scheduleCache.read(key);
      if (cached == null) rethrow;
      return _parseRaspisanieRows(cached);
    } finally {
      logTiming('query.raspisanie.end');
    }
  }

  Future<List<RaspisanieEntry>?> fetchCached({
    List<int>? groupIds,
    List<int>? teacherIds,
    List<String>? classrooms,
    DateTime? from,
    DateTime? to,
  }) async {
    final rawMaps = await _scheduleCache.read(_scheduleCacheKey(
      groupIds: groupIds,
      teacherIds: teacherIds,
      classrooms: classrooms,
      from: from,
      to: to,
    ));
    if (rawMaps == null) return null;
    return _parseRaspisanieRows(rawMaps);
  }

  Future<List<RaspisanieEntry>> fetchFresh({
    List<int>? groupIds,
    List<int>? teacherIds,
    List<String>? classrooms,
    DateTime? from,
    DateTime? to,
  }) async {
    final result = await _client.query(_raspisanieOptions(
      groupIds: groupIds,
      teacherIds: teacherIds,
      classrooms: classrooms,
      from: from,
      to: to,
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    final rawMaps = _raspisanieRawRows(result);
    await _scheduleCache.write(
      _scheduleCacheKey(
        groupIds: groupIds,
        teacherIds: teacherIds,
        classrooms: classrooms,
        from: from,
        to: to,
      ),
      rawMaps,
    );
    return _parseRaspisanieRows(rawMaps);
  }

  Future<void> refreshFresh({
    List<int>? groupIds,
    List<int>? teacherIds,
    List<String>? classrooms,
    DateTime? from,
    DateTime? to,
  }) async {
    final result = await _client.query(_raspisanieOptions(
      groupIds: groupIds,
      teacherIds: teacherIds,
      classrooms: classrooms,
      from: from,
      to: to,
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    final rawMaps = _raspisanieRawRows(result);
    await _scheduleCache.write(
      _scheduleCacheKey(
        groupIds: groupIds,
        teacherIds: teacherIds,
        classrooms: classrooms,
        from: from,
        to: to,
      ),
      rawMaps,
    );
  }

  Future<List<NamedRef>> fetchGroups() async {
    try {
      return await fetchGroupsFresh();
    } on OperationException {
      final cached = await fetchGroupsCached();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<List<NamedRef>?> fetchGroupsCached() async {
    final cached = await _offlineCache.readRows(_groupsCacheKey);
    if (cached == null) return null;
    return sortGroups(cached.map(NamedRef.fromJson).toList());
  }

  Future<List<NamedRef>> fetchGroupsFresh() async {
    final r = await _client.query(QueryOptions(
      document: gql(groupsQuery),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final rawMaps = _rawRefRows(r, 'group');
    await _offlineCache.writeRows(_groupsCacheKey, rawMaps);
    return sortGroups(rawMaps.map(NamedRef.fromJson).toList());
  }

  Future<List<NamedRef>> fetchTeachers() async {
    try {
      return await fetchTeachersFresh();
    } on OperationException {
      final cached = await fetchTeachersCached();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<List<NamedRef>?> fetchTeachersCached() async {
    final cached = await _offlineCache.readRows(_teachersCacheKey);
    if (cached == null) return null;
    return sortTeachers(cached.map(NamedRef.fromJson).toList());
  }

  Future<List<NamedRef>> fetchTeachersFresh() async {
    final r = await _client.query(QueryOptions(
      document: gql(teachersQuery),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final rawMaps = _rawRefRows(r, 'teacher');
    await _offlineCache.writeRows(_teachersCacheKey, rawMaps);
    return sortTeachers(rawMaps.map(NamedRef.fromJson).toList());
  }

  Future<List<String>> fetchClassrooms() async {
    try {
      return await fetchClassroomsFresh();
    } on OperationException {
      final cached = await fetchClassroomsCached();
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<List<String>?> fetchClassroomsCached() async {
    final cached = await _offlineCache.readObject(_classroomsCacheKey);
    final rooms = (cached?['rooms'] as List?)?.cast<String>();
    if (rooms == null) return null;
    return sortRooms(rooms);
  }

  Future<List<String>> fetchClassroomsFresh() async {
    final r = await _client.query(QueryOptions(
      document: gql(classroomsQuery),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final rooms = ((r.data?['classrooms'] as List?) ?? const [])
        .map((room) => room.toString())
        .toList(growable: false);
    await _offlineCache.writeObject(_classroomsCacheKey, {'rooms': rooms});
    return sortRooms(rooms);
  }

  Future<DayNote?> fetchDayNote(DateTime date) async {
    try {
      return await fetchDayNoteFresh(date);
    } on OperationException {
      final cached = await fetchDayNoteCached(date);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<DayNote?> fetchDayNoteCached(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    final cached = await _offlineCache.readObject(_dayNoteCacheKey(d));
    if (cached == null) return null;
    return DayNote.fromJson(cached);
  }

  Future<DayNote?> fetchDayNoteFresh(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    final cacheKey = _dayNoteCacheKey(d);
    final r = await _client.query(QueryOptions(
      document: gql(dayNoteQuery),
      variables: {'date': _isoDate(d)},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final raw = r.data?['dayNote'];
    if (raw == null) {
      await _offlineCache.remove(cacheKey);
      return null;
    }
    final map =
        Map<String, dynamic>.from((raw as Map).cast<dynamic, dynamic>());
    await _offlineCache.writeObject(cacheKey, map);
    return DayNote.fromJson(map);
  }

  Future<List<DayNote>> fetchDayNotesRange(DateTime from, DateTime to) async {
    try {
      return await fetchDayNotesRangeFresh(from, to);
    } on OperationException {
      final cached = await fetchDayNotesRangeCached(from, to);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<List<DayNote>?> fetchDayNotesRangeCached(
    DateTime from,
    DateTime to,
  ) async {
    final cached =
        await _offlineCache.readRows(_dayNotesRangeCacheKey(from, to));
    if (cached == null) return null;
    return cached.map(DayNote.fromJson).toList(growable: false);
  }

  Future<List<DayNote>> fetchDayNotesRangeFresh(
    DateTime from,
    DateTime to,
  ) async {
    final cacheKey = _dayNotesRangeCacheKey(from, to);
    final r = await _client.query(QueryOptions(
      document: gql(dayNotesRangeQuery),
      variables: {'from': _isoDate(from), 'to': _isoDate(to)},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final rawMaps = ((r.data?['dayNotes'] as List?) ?? const [])
        .cast<Map>()
        .map((row) => Map<String, dynamic>.from(row.cast<dynamic, dynamic>()))
        .toList(growable: false);
    await _offlineCache.writeRows(cacheKey, rawMaps);
    for (final raw in rawMaps) {
      final rawDate = raw['date'];
      if (rawDate is String) {
        await _offlineCache.writeObject('dayNote:$rawDate', raw);
      }
    }
    return rawMaps.map(DayNote.fromJson).toList(growable: false);
  }

  Future<DayNote> setDayNote(DateTime date, String body) async {
    final r = await _client.mutate(MutationOptions(
      document: gql(setDayNoteMutation),
      variables: {'date': _isoDate(date), 'body': body},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    final raw =
        Map<String, dynamic>.from((r.data!['setDayNote'] as Map).cast());
    await _offlineCache.writeObject(_dayNoteCacheKey(date), raw);
    await _offlineCache.removeByKeyPrefix(_dayNotesRangeCachePrefix);
    return DayNote.fromJson(raw);
  }

  Future<bool> deleteDayNote(DateTime date) async {
    final r = await _client.mutate(MutationOptions(
      document: gql(deleteDayNoteMutation),
      variables: {'date': _isoDate(date)},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) throw r.exception!;
    await _offlineCache.remove(_dayNoteCacheKey(date));
    await _offlineCache.removeByKeyPrefix(_dayNotesRangeCachePrefix);
    return r.data?['deleteDayNote'] as bool? ?? false;
  }

  static String? _isoDate(DateTime? d) {
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  ScheduleCacheKey _scheduleCacheKey({
    List<int>? groupIds,
    List<int>? teacherIds,
    List<String>? classrooms,
    DateTime? from,
    DateTime? to,
  }) =>
      ScheduleCacheKey(
        groupIds: groupIds,
        teacherIds: teacherIds,
        classrooms: classrooms,
        from: _isoDate(from),
        to: _isoDate(to),
      );
}

final raspisanieRepositoryProvider = Provider<RaspisanieRepository>(
  (ref) => RaspisanieRepository(
    ref.watch(graphqlClientProvider),
    scheduleCache: ref.watch(scheduleCacheStoreProvider),
    offlineCache: ref.watch(offlineJsonCacheStoreProvider),
  ),
);

String _dayNoteCacheKey(DateTime date) =>
    'dayNote:${RaspisanieRepository._isoDate(date)}';

const _dayNotesRangeCachePrefix = 'dayNotes:';

String _dayNotesRangeCacheKey(DateTime from, DateTime to) =>
    '$_dayNotesRangeCachePrefix${RaspisanieRepository._isoDate(from)}:${RaspisanieRepository._isoDate(to)}';

const _groupsCacheKey = 'refs:groups';
const _teachersCacheKey = 'refs:teachers';
const _classroomsCacheKey = 'refs:classrooms';

const _refListAutoRefreshTtl = Duration(minutes: 10);
final _backgroundRefreshLastAt = <String, DateTime>{};

bool _backgroundRefreshDue(String key, Duration ttl) {
  final last = _backgroundRefreshLastAt[key];
  if (last == null) return true;
  return DateTime.now().difference(last) > ttl;
}

void _markBackgroundRefresh(String key) {
  _backgroundRefreshLastAt[key] = DateTime.now();
}

void _refreshProviderInBackground(
  Ref ref,
  String key,
  Future<void> Function() refresh, {
  Duration ttl = _refListAutoRefreshTtl,
}) {
  if (!_backgroundRefreshDue(key, ttl)) return;
  _markBackgroundRefresh(key);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  unawaited(() async {
    try {
      await refresh();
      if (!disposed) ref.invalidateSelf();
    } catch (_) {}
  }());
}

final allGroupsProvider = FutureProvider<List<NamedRef>>((ref) async {
  final repo = ref.watch(raspisanieRepositoryProvider);
  final cached = await repo.fetchGroupsCached();
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      _groupsCacheKey,
      () async => repo.fetchGroupsFresh(),
    );
    return cached;
  }
  return repo.fetchGroups();
});

final allTeachersProvider = FutureProvider<List<NamedRef>>((ref) async {
  final repo = ref.watch(raspisanieRepositoryProvider);
  final cached = await repo.fetchTeachersCached();
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      _teachersCacheKey,
      () async => repo.fetchTeachersFresh(),
    );
    return cached;
  }
  return repo.fetchTeachers();
});

final allClassroomsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(raspisanieRepositoryProvider);
  final cached = await repo.fetchClassroomsCached();
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      _classroomsCacheKey,
      () async => repo.fetchClassroomsFresh(),
    );
    return cached;
  }
  return repo.fetchClassrooms();
});

/// Composite key for the schedule family: month + active filter. Each
/// (month, filter) combination is cached independently so flipping between
/// filters doesn't evict prior data.
typedef MonthFilterParams = ({
  DateTime month,
  int? groupId,
  int? teacherId,
  String? classroom,
});

MonthFilterParams monthFilterParamsFor(DateTime month, ScheduleFilters f) => (
      month: month,
      groupId: f.groupId,
      teacherId: f.teacherId,
      classroom: f.classroom,
    );

/// Schedule-change pushes need to force active providers to rerun for the
/// affected month once. The month provider paints cached rows first, then
/// refreshes the network and invalidates itself so fresh rows repaint.
class ScheduleForceRefresh extends Notifier<Set<MonthFilterParams>> {
  @override
  Set<MonthFilterParams> build() => const <MonthFilterParams>{};

  void request(Iterable<MonthFilterParams> params) {
    final next = {...state, ...params};
    if (next.length == state.length) return;
    state = next;
  }

  void consume(MonthFilterParams params) {
    if (!state.contains(params)) return;
    final next = {...state}..remove(params);
    state = next;
  }
}

final scheduleForceRefreshProvider =
    NotifierProvider<ScheduleForceRefresh, Set<MonthFilterParams>>(
  ScheduleForceRefresh.new,
);

const _scheduleAutoRefreshTtl = Duration(minutes: 3);
final _scheduleLastNetworkRefreshAt = <MonthFilterParams, DateTime>{};
const _noteAutoRefreshTtl = Duration(minutes: 3);

bool _scheduleAutoRefreshDue(MonthFilterParams params) {
  final last = _scheduleLastNetworkRefreshAt[params];
  if (last == null) return true;
  return DateTime.now().difference(last) > _scheduleAutoRefreshTtl;
}

void _markScheduleNetworkRefresh(MonthFilterParams params) {
  _scheduleLastNetworkRefreshAt[params] = DateTime.now();
}

/// Fetch raspisanie for a (month, filter) pair. Kept alive so adjacent-month
/// and previously-selected-filter caches survive for instant back-navigation.
final monthRaspisanieByMonthProvider =
    FutureProvider.family<List<RaspisanieEntry>, MonthFilterParams>(
        (ref, params) async {
  ref.keepAlive();
  final forceNetwork = ref.watch(scheduleForceRefreshProvider
      .select((pending) => pending.contains(params)));
  if (params.groupId == null &&
      params.teacherId == null &&
      params.classroom == null) {
    if (forceNetwork) {
      ref.read(scheduleForceRefreshProvider.notifier).consume(params);
    }
    return const <RaspisanieEntry>[];
  }
  final repo = ref.watch(raspisanieRepositoryProvider);
  final groupIds = params.groupId == null ? null : [params.groupId!];
  final teacherIds = params.teacherId == null ? null : [params.teacherId!];
  final classrooms = params.classroom == null ? null : [params.classroom!];
  final from = gridStartFor(params.month);
  final to = gridEndFor(params.month);

  final cached = await repo.fetchCached(
    groupIds: groupIds,
    teacherIds: teacherIds,
    classrooms: classrooms,
    from: from,
    to: to,
  );
  if (cached != null) {
    final shouldRefresh = forceNetwork || _scheduleAutoRefreshDue(params);
    if (shouldRefresh) {
      _markScheduleNetworkRefresh(params);
      var disposed = false;
      ref.onDispose(() => disposed = true);
      unawaited(() async {
        try {
          await repo.refreshFresh(
            groupIds: groupIds,
            teacherIds: teacherIds,
            classrooms: classrooms,
            from: from,
            to: to,
          );
          if (disposed) return;
          if (forceNetwork) {
            ref.read(scheduleForceRefreshProvider.notifier).consume(params);
          }
          ref.invalidateSelf();
        } catch (_) {
          // Keep rendering the cached month. A future explicit refresh,
          // resume, or push will try again.
        }
      }());
    }
    return cached;
  }

  try {
    return await repo.fetch(
      groupIds: groupIds,
      teacherIds: teacherIds,
      classrooms: classrooms,
      from: from,
      to: to,
      fetchPolicy: FetchPolicy.networkOnly,
    );
  } finally {
    _markScheduleNetworkRefresh(params);
    if (forceNetwork) {
      ref.read(scheduleForceRefreshProvider.notifier).consume(params);
    }
  }
});

final monthRaspisanieProvider =
    Provider<AsyncValue<List<RaspisanieEntry>>>((ref) {
  final month = ref.watch(displayedMonthProvider);
  final filters = ref.watch(scheduleFiltersProvider);
  return ref.watch(
      monthRaspisanieByMonthProvider(monthFilterParamsFor(month, filters)));
});

/// Warm the adjacent-month caches so arrowing left/right is instant. Consumed
/// by the Schedule screen via `ref.watch`; side-effectful reads populate the
/// family providers and rely on `keepAlive` for retention.
///
/// Gated on the current month's data being settled so a cold-launch (or a
/// filter switch) doesn't pile prev+next month parses on top of the visible
/// month — the `compute()`-wrapped parser still consumes a worker, and
/// firing 3 of them concurrently squanders the wins from Item 1.
final adjacentMonthPreloadProvider = Provider<void>((ref) {
  final month = ref.watch(displayedMonthProvider);
  final filters = ref.watch(scheduleFiltersProvider);
  final current = ref.watch(
      monthRaspisanieByMonthProvider(monthFilterParamsFor(month, filters)));
  // Hold off until the visible month has data. `asData != null` covers both
  // the first successful fetch and stale-while-revalidate refreshes.
  if (current.asData == null) return;
  final prev = DateTime(month.year, month.month - 1, 1);
  final next = DateTime(month.year, month.month + 1, 1);
  ref.watch(
      monthRaspisanieByMonthProvider(monthFilterParamsFor(prev, filters)));
  ref.watch(
      monthRaspisanieByMonthProvider(monthFilterParamsFor(next, filters)));
  ref.watch(monthNotesByMonthProvider(prev));
  ref.watch(monthNotesByMonthProvider(next));
  ref.watch(pinnedNotesForMonthProvider(prev));
  ref.watch(pinnedNotesForMonthProvider(next));
  ref.watch(notificationsForMonthProvider(prev));
  ref.watch(notificationsForMonthProvider(next));
});

final dayNoteProvider =
    FutureProvider.family<DayNote?, DateTime>((ref, date) async {
  // Flush when auth flips (prevents stale notes from a previous account).
  ref.watch(authEpochProvider);
  final d = DateTime(date.year, date.month, date.day);
  final queued =
      ref.watch(noteQueueProvider).asData?.value ?? const <QueuedNoteOp>[];
  final op = queuedOpForDate(queued, d);

  DayNote? overlay(DayNote? serverNote) {
    if (op == null) return serverNote;
    if (op.type == QueuedNoteOpType.delete) return null;
    return DayNote(
      id: serverNote?.id ?? 0,
      date: d,
      body: op.body,
      updatedAt: op.queuedAt.toIso8601String(),
    );
  }

  final storage = ref.watch(noteStorageProvider);
  final cached = await storage.fetchCached(d);
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      _dayNoteCacheKey(d),
      () async => storage.fetchFresh(d),
      ttl: _noteAutoRefreshTtl,
    );
    return overlay(cached);
  }
  if (op != null) {
    _refreshProviderInBackground(
      ref,
      _dayNoteCacheKey(d),
      () async => storage.fetchFresh(d),
      ttl: _noteAutoRefreshTtl,
    );
    return overlay(null);
  }

  try {
    return overlay(await storage.fetch(d));
  } catch (_) {
    // Offline / network blip. If we have a queued op we can still render it;
    // otherwise rethrow so the caller sees the error.
    if (op == null) rethrow;
  }
  return overlay(null);
});

/// Month-wide note outlines for `month`. Kept alive so adjacent-month
/// preloads survive navigation.
final monthNotesByMonthProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
  ref.keepAlive();
  ref.watch(authEpochProvider);
  final storage = ref.watch(noteStorageProvider);
  final ops =
      ref.watch(noteQueueProvider).asData?.value ?? const <QueuedNoteOp>[];
  final from = gridStartFor(month);
  final to = gridEndFor(month);

  Set<DateTime> overlay(Set<DateTime> server) {
    final out = Set<DateTime>.from(server);
    for (final op in ops) {
      final d = DateTime(op.date.year, op.date.month, op.date.day);
      if (d.isBefore(from) || d.isAfter(to)) continue;
      if (op.type == QueuedNoteOpType.delete || op.body.trim().isEmpty) {
        out.remove(d);
      } else {
        out.add(d);
      }
    }
    return out;
  }

  final cacheKey = _dayNotesRangeCacheKey(from, to);
  final cached = await storage.fetchRangeCached(from, to);
  if (cached != null) {
    _refreshProviderInBackground(
      ref,
      cacheKey,
      () async => storage.fetchRangeFresh(from, to),
      ttl: _noteAutoRefreshTtl,
    );
    return overlay(cached);
  }
  if (ops.isNotEmpty) {
    _refreshProviderInBackground(
      ref,
      cacheKey,
      () async => storage.fetchRangeFresh(from, to),
      ttl: _noteAutoRefreshTtl,
    );
    return overlay(<DateTime>{});
  }

  try {
    return overlay(await storage.fetchRange(from, to));
  } catch (_) {
    return overlay(<DateTime>{});
  }
});

final monthNotesProvider = Provider<AsyncValue<Set<DateTime>>>((ref) {
  final month = ref.watch(displayedMonthProvider);
  return ref.watch(monthNotesByMonthProvider(month));
});

/// Shablon-derived weekday/parity coverage for the displayed month.
///
/// Lessons that the server flagged as `isOverride` are excluded so that an
/// operator-cancelled or moved lesson cannot flip a calendar day's colour.
/// The pattern reports which weekdays the canonical shablon has lessons on,
/// and — separately — which (weekday, parity) slots have shablon entries.
class ShablonWeekdayPattern {
  ShablonWeekdayPattern({
    required this.weekdays,
    required this.evenWeekdays,
    required this.oddWeekdays,
    required this.hasEvenOddSplit,
  });
  final Set<int> weekdays;
  final Set<int> evenWeekdays;
  final Set<int> oddWeekdays;

  /// True when the shablon has different (weekday, slot, subject, subgroup)
  /// coverage between even and odd parities — i.e. the schedule is NOT the
  /// same every week. Used by [DayColoringMode.auto] to pick evenOdd vs
  /// hasLessons automatically.
  final bool hasEvenOddSplit;

  bool hasLessonsOn(DateTime date) => weekdays.contains(date.weekday);
  bool hasParityLessonsOn(DateTime date) {
    final wd = date.weekday;
    return _isEvenWeek(date)
        ? evenWeekdays.contains(wd)
        : oddWeekdays.contains(wd);
  }

  static const empty = _emptyShablon;
}

const _emptyShablon = _EmptyShablon();

class _EmptyShablon implements ShablonWeekdayPattern {
  const _EmptyShablon();
  @override
  Set<int> get weekdays => const <int>{};
  @override
  Set<int> get evenWeekdays => const <int>{};
  @override
  Set<int> get oddWeekdays => const <int>{};
  @override
  bool get hasEvenOddSplit => false;
  @override
  bool hasLessonsOn(DateTime _) => false;
  @override
  bool hasParityLessonsOn(DateTime _) => false;
}

ShablonWeekdayPattern shablonPatternFromEntries(
    Iterable<RaspisanieEntry> entries) {
  final weekdays = <int>{};
  final evenWeekdays = <int>{};
  final oddWeekdays = <int>{};
  // (weekday, slot, subgroup, subjectId) signature sets per parity — used to
  // detect whether the two halves of the shablon differ at all. Overrides are
  // excluded since they reflect operator edits, not template shape.
  final evenSigs = <String>{};
  final oddSigs = <String>{};
  for (final e in entries) {
    if (e.isOverride) continue;
    final wd = e.date.weekday;
    weekdays.add(wd);
    final sig = '$wd|${e.subjectNumber}|${e.subgroup ?? 0}|${e.subject.id}';
    if (_isEvenWeek(e.date)) {
      evenWeekdays.add(wd);
      evenSigs.add(sig);
    } else {
      oddWeekdays.add(wd);
      oddSigs.add(sig);
    }
  }
  // If either half is empty we've only observed one parity (small dataset,
  // week-aligned fetch boundaries) — can't prove a split, default to false.
  final bool split = evenSigs.isNotEmpty &&
      oddSigs.isNotEmpty &&
      !_setEquals(evenSigs, oddSigs);
  return ShablonWeekdayPattern(
    weekdays: weekdays,
    evenWeekdays: evenWeekdays,
    oddWeekdays: oddWeekdays,
    hasEvenOddSplit: split,
  );
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final x in a) {
    if (!b.contains(x)) return false;
  }
  return true;
}

bool _isEvenWeek(DateTime d) => week_math.isEvenWeek(d);
