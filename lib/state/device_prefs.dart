import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/graphql_config.dart';
import '../api/queries.dart';

/// Current device's FCM token. Written by push_manager as soon as a token is
/// available (post-permission-grant, or on token refresh). Null means "not yet
/// resolved" — the Settings screen treats this as an indeterminate state and
/// shows toggles OFF with an explanatory subtitle, never silently writing
/// prefs to nowhere.
class CurrentFcmTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

final currentFcmTokenProvider =
    NotifierProvider<CurrentFcmTokenNotifier, String?>(
  CurrentFcmTokenNotifier.new,
);

class DevicePrefs {
  final String deviceToken;
  final bool news;
  final bool announcements;
  final bool scheduleChanges;

  const DevicePrefs({
    required this.deviceToken,
    required this.news,
    required this.announcements,
    required this.scheduleChanges,
  });

  factory DevicePrefs.fromJson(Map<String, dynamic> j) => DevicePrefs(
        deviceToken: j['deviceToken'] as String,
        news: j['news'] as bool? ?? true,
        announcements: j['announcements'] as bool? ?? true,
        scheduleChanges: j['scheduleChanges'] as bool? ?? true,
      );

  Map<String, dynamic> toCacheJson() => {
        'news': news,
        'announcements': announcements,
        'scheduleChanges': scheduleChanges,
      };

  DevicePrefs copyWith({
    bool? news,
    bool? announcements,
    bool? scheduleChanges,
  }) =>
      DevicePrefs(
        deviceToken: deviceToken,
        news: news ?? this.news,
        announcements: announcements ?? this.announcements,
        scheduleChanges: scheduleChanges ?? this.scheduleChanges,
      );
}

/// FNV-1a 32-bit hash of the FCM token. Non-cryptographic — only used to
/// avoid dumping raw tokens into the SharedPreferences keyspace. 32-bit is
/// chosen over 64-bit because `dart2js` rejects `0x...`-literal 64-bit
/// constants (web-unsafe), and collisions here are harmless: the worst case
/// is two tokens sharing a cache entry, which gets overwritten on next read.
String _tokenHash(String t) {
  var hash = 0x811c9dc5;
  for (final b in utf8.encode(t)) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16);
}

String _cacheKey(String token) => 'device_push_prefs_v1_${_tokenHash(token)}';

/// Stale-while-revalidate window for the per-device push prefs query. The
/// settings screen calls [DevicePrefsNotifier.refresh] on every mount so
/// the toggles reflect any server-side row created after a token rotation,
/// but mounting Settings is a frequent gesture (tab switch, drag-down to
/// dismiss and back up) and the refresh used to fire a network call every
/// single time. Within this window, refresh() returns early — no UX impact
/// because the provider state is still good — and a stale-past-TTL mount
/// gets a real fetch.
@visibleForTesting
const kDevicePrefsRefreshTtl = Duration(minutes: 5);

class DevicePrefsNotifier extends AsyncNotifier<DevicePrefs?> {
  // Stamped on every successful network fetch (so callers' [refresh] calls
  // can be deduped within the TTL). Ref-instance state — survives across
  // refresh() calls because the AsyncNotifier itself is non-autoDispose.
  DateTime? _lastFetchedAt;

  @override
  Future<DevicePrefs?> build() async {
    final token = ref.watch(currentFcmTokenProvider);
    if (token == null || token.isEmpty) return null;
    final cached = await _readCache(token);
    // Kick off a network reconcile without blocking the first frame on it.
    unawaited(_fetch(token));
    return cached;
  }

  /// Force a network re-fetch (e.g. Settings screen mounts, or token rotated
  /// and the old prefs row is no longer relevant). TTL-deduped — repeated
  /// calls within [_kDevicePrefsRefreshTtl] are no-ops to keep tab-switch
  /// gestures from firing redundant `devicePushPrefs` queries.
  Future<void> refresh() async {
    final token = ref.read(currentFcmTokenProvider);
    if (token == null || token.isEmpty) return;
    final last = _lastFetchedAt;
    if (last != null &&
        DateTime.now().difference(last) < kDevicePrefsRefreshTtl) {
      return;
    }
    await fetchPrefsForToken(token);
  }

  /// Network-side of [refresh], split out so tests can override the fetch
  /// without running a real GraphQL query. Production callers must always
  /// go through [refresh] (which applies the TTL gate); this entry point
  /// exists purely for the deduplication test.
  @visibleForTesting
  Future<void> fetchPrefsForToken(String token) => _fetch(token);

  /// Test seam: stamp the dedup timestamp without performing a real fetch.
  /// Callers that override [fetchPrefsForToken] in tests need to drive the
  /// TTL state forward in lieu of the production [_fetch] doing so.
  @visibleForTesting
  void markFetchedAtForTesting(DateTime t) {
    _lastFetchedAt = t;
  }

  Future<DevicePrefs?> _readCache(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(token));
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DevicePrefs(
        deviceToken: token,
        news: j['news'] as bool? ?? true,
        announcements: j['announcements'] as bool? ?? true,
        scheduleChanges: j['scheduleChanges'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(DevicePrefs p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(p.deviceToken), jsonEncode(p.toCacheJson()));
    } catch (_) {}
  }

  Future<void> _fetch(String token) async {
    try {
      final client = ref.read(graphqlClientProvider);
      final r = await client.query(QueryOptions(
        document: gql(devicePushPrefsQuery),
        variables: {'deviceToken': token},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (r.hasException) return;
      final raw = r.data?['devicePushPrefs'];
      // Token may still be unregistered server-side (e.g. registration race);
      // leave state untouched — the backend will create an all-on row on the
      // first updateDevicePushPrefs call.
      if (raw == null) return;
      if (ref.read(currentFcmTokenProvider) != token) return;
      final p = DevicePrefs.fromJson(raw as Map<String, dynamic>);
      await _writeCache(p);
      state = AsyncValue.data(p);
      _lastFetchedAt = DateTime.now();
    } catch (_) {}
  }

  /// Flip one category. Optimistically updates local state + cache; reverts
  /// on server error and rethrows the message for the caller to surface.
  Future<void> applyPatch({
    bool? news,
    bool? announcements,
    bool? scheduleChanges,
  }) async {
    final token = ref.read(currentFcmTokenProvider);
    if (token == null || token.isEmpty) {
      throw 'device token not available';
    }
    final current = state.asData?.value ??
        DevicePrefs(
          deviceToken: token,
          news: true,
          announcements: true,
          scheduleChanges: true,
        );
    final patched = current.copyWith(
      news: news,
      announcements: announcements,
      scheduleChanges: scheduleChanges,
    );
    state = AsyncValue.data(patched);
    unawaited(_writeCache(patched));
    final client = ref.read(graphqlClientProvider);
    final prefsInput = <String, dynamic>{};
    if (news != null) prefsInput['news'] = news;
    if (announcements != null) prefsInput['announcements'] = announcements;
    if (scheduleChanges != null) prefsInput['scheduleChanges'] = scheduleChanges;
    final r = await client.mutate(MutationOptions(
      document: gql(updateDevicePushPrefsMutation),
      variables: {
        'deviceToken': token,
        'prefs': prefsInput,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) {
      state = AsyncValue.data(current);
      unawaited(_writeCache(current));
      final e = r.exception!;
      if (e.graphqlErrors.isNotEmpty) throw e.graphqlErrors.first.message;
      throw e.linkException?.toString() ?? 'Network error';
    }
    final raw = r.data?['updateDevicePushPrefs'];
    if (raw != null) {
      final server = DevicePrefs.fromJson(raw as Map<String, dynamic>);
      state = AsyncValue.data(server);
      unawaited(_writeCache(server));
    }
  }
}

final devicePrefsProvider =
    AsyncNotifierProvider<DevicePrefsNotifier, DevicePrefs?>(
  DevicePrefsNotifier.new,
);
