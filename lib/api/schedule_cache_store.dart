import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable key for one schedule query window. The UI only ever needs a small
/// number of these persisted: current month/filter, plus nearby months for
/// instant navigation.
class ScheduleCacheKey {
  ScheduleCacheKey({
    List<int>? groupIds,
    List<int>? teacherIds,
    List<String>? classrooms,
    required String? from,
    required String? to,
  })  : groupIds = _sortedInts(groupIds),
        teacherIds = _sortedInts(teacherIds),
        classrooms = _sortedStrings(classrooms),
        from = from ?? '',
        to = to ?? '';

  final List<int>? groupIds;
  final List<int>? teacherIds;
  final List<String>? classrooms;
  final String from;
  final String to;

  String get stableKey => jsonEncode({
        'classrooms': classrooms,
        'from': from,
        'groups': groupIds,
        'teachers': teacherIds,
        'to': to,
      });

  String get cacheId => _fnv1a32(stableKey);

  static List<int>? _sortedInts(List<int>? values) {
    if (values == null || values.isEmpty) return null;
    return [...values]..sort();
  }

  static List<String>? _sortedStrings(List<String>? values) {
    if (values == null || values.isEmpty) return null;
    return [...values]..sort();
  }
}

abstract class ScheduleCacheStore {
  Future<List<Map<String, dynamic>>?> read(ScheduleCacheKey key);
  Future<void> write(ScheduleCacheKey key, List<Map<String, dynamic>> rows);
  Future<void> clear();
}

class DisabledScheduleCacheStore implements ScheduleCacheStore {
  const DisabledScheduleCacheStore();

  @override
  Future<List<Map<String, dynamic>>?> read(ScheduleCacheKey key) async => null;

  @override
  Future<void> write(
      ScheduleCacheKey key, List<Map<String, dynamic>> rows) async {}

  @override
  Future<void> clear() async {}
}

/// Bounded replacement for graphql_flutter's persistent HiveStore.
///
/// The old cache persisted every normalized GraphQL response into one Hive box
/// that had to be opened eagerly on cold start. This store persists only raw
/// schedule query payloads, keeps a tiny LRU manifest, and never participates
/// in GraphQL normalization.
class SharedPrefsScheduleCacheStore implements ScheduleCacheStore {
  const SharedPrefsScheduleCacheStore({
    this.maxEntries = 8,
    this.maxTotalBytes = 3 * 1024 * 1024,
    this.maxEntryBytes = 1024 * 1024,
  });

  static const instance = SharedPrefsScheduleCacheStore();

  @visibleForTesting
  static const manifestKey = 'schedule_query_cache_manifest_v1';

  @visibleForTesting
  static const entryPrefix = 'schedule_query_cache_entry_v1_';

  final int maxEntries;
  final int maxTotalBytes;
  final int maxEntryBytes;

  @override
  Future<List<Map<String, dynamic>>?> read(ScheduleCacheKey key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entryKey = '$entryPrefix${key.cacheId}';
      final raw = prefs.getString(entryKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded.cast<dynamic, dynamic>());
      if (map['key'] != key.stableKey) return null;
      final rows = map['rows'];
      if (rows is! List) return null;
      await _touch(prefs, key.cacheId);
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row.cast<dynamic, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(
    ScheduleCacheKey key,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final encoded = jsonEncode({
        'version': 1,
        'key': key.stableKey,
        'savedAt': now,
        'rows': rows,
      });
      final bytes = utf8.encode(encoded).length;
      final entryKey = '$entryPrefix${key.cacheId}';
      final manifest = _readManifest(prefs);
      if (bytes > maxEntryBytes) {
        await prefs.remove(entryKey);
        manifest.remove(key.cacheId);
        await _writeManifest(prefs, manifest);
        return;
      }
      await prefs.setString(entryKey, encoded);
      manifest[key.cacheId] = _ScheduleCacheMeta(
        key: key.stableKey,
        savedAt: now,
        lastAccessedAt: now,
        bytes: bytes,
      );
      await _enforceBounds(prefs, manifest);
      await _writeManifest(prefs, manifest);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key == manifestKey || key.startsWith(entryPrefix))
          .toList(growable: false);
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  Future<void> _touch(SharedPreferences prefs, String id) async {
    final manifest = _readManifest(prefs);
    final meta = manifest[id];
    if (meta == null) return;
    manifest[id] = meta.copyWith(
      lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _writeManifest(prefs, manifest);
  }

  Map<String, _ScheduleCacheMeta> _readManifest(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(manifestKey);
      if (raw == null || raw.isEmpty) return <String, _ScheduleCacheMeta>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, _ScheduleCacheMeta>{};
      final out = <String, _ScheduleCacheMeta>{};
      for (final entry in decoded.entries) {
        final id = entry.key.toString();
        final value = entry.value;
        if (value is! Map) continue;
        final meta = _ScheduleCacheMeta.tryParse(value);
        if (meta != null) out[id] = meta;
      }
      return out;
    } catch (_) {
      return <String, _ScheduleCacheMeta>{};
    }
  }

  Future<void> _writeManifest(
    SharedPreferences prefs,
    Map<String, _ScheduleCacheMeta> manifest,
  ) {
    return prefs.setString(
      manifestKey,
      jsonEncode(manifest.map((id, meta) => MapEntry(id, meta.toJson()))),
    );
  }

  Future<void> _enforceBounds(
    SharedPreferences prefs,
    Map<String, _ScheduleCacheMeta> manifest,
  ) async {
    final knownEntryKeys = manifest.keys.map((id) => '$entryPrefix$id').toSet();
    final orphanKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(entryPrefix))
        .where((key) => !knownEntryKeys.contains(key))
        .toList(growable: false);
    for (final key in orphanKeys) {
      await prefs.remove(key);
    }

    int totalBytes = manifest.values.fold<int>(
      0,
      (sum, meta) => sum + meta.bytes,
    );
    final victims = manifest.entries.toList(growable: false)
      ..sort((a, b) => a.value.lastAccessedAt.compareTo(
            b.value.lastAccessedAt,
          ));
    for (final victim in victims) {
      if (manifest.length <= maxEntries && totalBytes <= maxTotalBytes) break;
      await prefs.remove('$entryPrefix${victim.key}');
      totalBytes -= victim.value.bytes;
      manifest.remove(victim.key);
    }
  }
}

class _ScheduleCacheMeta {
  const _ScheduleCacheMeta({
    required this.key,
    required this.savedAt,
    required this.lastAccessedAt,
    required this.bytes,
  });

  final String key;
  final int savedAt;
  final int lastAccessedAt;
  final int bytes;

  _ScheduleCacheMeta copyWith({int? lastAccessedAt}) => _ScheduleCacheMeta(
        key: key,
        savedAt: savedAt,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        bytes: bytes,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'savedAt': savedAt,
        'lastAccessedAt': lastAccessedAt,
        'bytes': bytes,
      };

  static _ScheduleCacheMeta? tryParse(Map<dynamic, dynamic> raw) {
    final key = raw['key'];
    final savedAt = raw['savedAt'];
    final lastAccessedAt = raw['lastAccessedAt'];
    final bytes = raw['bytes'];
    if (key is! String ||
        savedAt is! int ||
        lastAccessedAt is! int ||
        bytes is! int) {
      return null;
    }
    return _ScheduleCacheMeta(
      key: key,
      savedAt: savedAt,
      lastAccessedAt: lastAccessedAt,
      bytes: bytes,
    );
  }
}

String _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

final scheduleCacheStoreProvider = Provider<ScheduleCacheStore>(
  (_) => SharedPrefsScheduleCacheStore.instance,
);
