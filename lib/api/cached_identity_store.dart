import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last-known `me` payload so the auth resolver can seed the UI
/// with a previously-verified user identity on cold start without waiting on
/// the network. Independent of the GraphQL client cache — that cache is
/// memory-only, while this is a single self-contained snapshot keyed on a
/// stable string. Stored as JSON so future `me` schema changes can either
/// continue to deserialize via [AppUser.fromJson] or trigger a one-shot
/// reset (catching the parse exception on load).
class CachedIdentityStore {
  CachedIdentityStore._();

  /// Test-only constructor for fakes; production code uses
  /// [CachedIdentityStore.instance] which round-trips to SharedPreferences.
  @visibleForTesting
  CachedIdentityStore.forTesting();

  static final CachedIdentityStore instance = CachedIdentityStore._();

  static const _key = 'auth_cached_me_v1';

  Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> me) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(me));
    } catch (_) {
      // Plugin race / quota — non-fatal. Next successful refresh retries.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

final cachedIdentityStoreProvider =
    Provider<CachedIdentityStore>((_) => CachedIdentityStore.instance);
