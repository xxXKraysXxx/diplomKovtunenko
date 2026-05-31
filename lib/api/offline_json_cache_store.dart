import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class OfflineJsonCacheStore {
  Future<List<Map<String, dynamic>>?> readRows(String key);
  Future<void> writeRows(String key, List<Map<String, dynamic>> rows);
  Future<Map<String, dynamic>?> readObject(String key);
  Future<void> writeObject(String key, Map<String, dynamic> object);
  Future<void> remove(String key);
  Future<void> removeByKeyPrefix(String prefix);
  Future<void> clear();
}

class DisabledOfflineJsonCacheStore implements OfflineJsonCacheStore {
  const DisabledOfflineJsonCacheStore();

  @override
  Future<List<Map<String, dynamic>>?> readRows(String key) async => null;

  @override
  Future<void> writeRows(String key, List<Map<String, dynamic>> rows) async {}

  @override
  Future<Map<String, dynamic>?> readObject(String key) async => null;

  @override
  Future<void> writeObject(String key, Map<String, dynamic> object) async {}

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> removeByKeyPrefix(String prefix) async {}

  @override
  Future<void> clear() async {}
}

/// Small explicit offline cache for non-schedule GraphQL payloads.
///
/// This replaces the old "everything goes into GraphQL HiveStore" behavior
/// for features that still need cold-start/offline snapshots. It is bounded
/// hard enough to stay cheap when SharedPreferences is primed at startup.
class SharedPrefsOfflineJsonCacheStore implements OfflineJsonCacheStore {
  const SharedPrefsOfflineJsonCacheStore({
    this.maxEntries = 20,
    this.maxTotalBytes = 700 * 1024,
    this.maxEntryBytes = 250 * 1024,
  });

  static const instance = SharedPrefsOfflineJsonCacheStore();

  @visibleForTesting
  static const manifestKey = 'offline_json_cache_manifest_v1';

  @visibleForTesting
  static const entryPrefix = 'offline_json_cache_entry_v1_';

  final int maxEntries;
  final int maxTotalBytes;
  final int maxEntryBytes;

  @override
  Future<List<Map<String, dynamic>>?> readRows(String key) async {
    final payload = await _readPayload(key, expectedShape: 'rows');
    final rows = payload?['payload'];
    if (rows is! List) return null;
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row.cast<dynamic, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<void> writeRows(
    String key,
    List<Map<String, dynamic>> rows,
  ) async {
    await _writePayload(key, 'rows', rows);
  }

  @override
  Future<Map<String, dynamic>?> readObject(String key) async {
    final payload = await _readPayload(key, expectedShape: 'object');
    final object = payload?['payload'];
    if (object is! Map) return null;
    return Map<String, dynamic>.from(object.cast<dynamic, dynamic>());
  }

  @override
  Future<void> writeObject(String key, Map<String, dynamic> object) async {
    await _writePayload(key, 'object', object);
  }

  @override
  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = _fnv1a32(key);
      final manifest = _readManifest(prefs);
      manifest.remove(id);
      await prefs.remove('$entryPrefix$id');
      await _writeManifest(prefs, manifest);
    } catch (_) {}
  }

  @override
  Future<void> removeByKeyPrefix(String prefix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manifest = _readManifest(prefs);
      final victims = manifest.entries
          .where((entry) => entry.value.key.startsWith(prefix))
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final id in victims) {
        manifest.remove(id);
        await prefs.remove('$entryPrefix$id');
      }
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

  Future<Map<String, dynamic>?> _readPayload(
    String key, {
    required String expectedShape,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = _fnv1a32(key);
      final raw = prefs.getString('$entryPrefix$id');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded.cast<dynamic, dynamic>());
      if (map['key'] != key || map['shape'] != expectedShape) return null;
      await _touch(prefs, id);
      return map;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePayload(
    String key,
    String shape,
    Object payload,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = _fnv1a32(key);
      final now = DateTime.now().millisecondsSinceEpoch;
      final encoded = jsonEncode({
        'version': 1,
        'key': key,
        'shape': shape,
        'savedAt': now,
        'payload': payload,
      });
      final bytes = utf8.encode(encoded).length;
      final manifest = _readManifest(prefs);
      if (bytes > maxEntryBytes) {
        manifest.remove(id);
        await prefs.remove('$entryPrefix$id');
        await _writeManifest(prefs, manifest);
        return;
      }
      await prefs.setString('$entryPrefix$id', encoded);
      manifest[id] = _OfflineCacheMeta(
        key: key,
        savedAt: now,
        lastAccessedAt: now,
        bytes: bytes,
      );
      await _enforceBounds(prefs, manifest);
      await _writeManifest(prefs, manifest);
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

  Map<String, _OfflineCacheMeta> _readManifest(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(manifestKey);
      if (raw == null || raw.isEmpty) return <String, _OfflineCacheMeta>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, _OfflineCacheMeta>{};
      final out = <String, _OfflineCacheMeta>{};
      for (final entry in decoded.entries) {
        final id = entry.key.toString();
        final value = entry.value;
        if (value is! Map) continue;
        final meta = _OfflineCacheMeta.tryParse(value);
        if (meta != null) out[id] = meta;
      }
      return out;
    } catch (_) {
      return <String, _OfflineCacheMeta>{};
    }
  }

  Future<void> _writeManifest(
    SharedPreferences prefs,
    Map<String, _OfflineCacheMeta> manifest,
  ) {
    return prefs.setString(
      manifestKey,
      jsonEncode(manifest.map((id, meta) => MapEntry(id, meta.toJson()))),
    );
  }

  Future<void> _enforceBounds(
    SharedPreferences prefs,
    Map<String, _OfflineCacheMeta> manifest,
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

class _OfflineCacheMeta {
  const _OfflineCacheMeta({
    required this.key,
    required this.savedAt,
    required this.lastAccessedAt,
    required this.bytes,
  });

  final String key;
  final int savedAt;
  final int lastAccessedAt;
  final int bytes;

  _OfflineCacheMeta copyWith({int? lastAccessedAt}) => _OfflineCacheMeta(
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

  static _OfflineCacheMeta? tryParse(Map<dynamic, dynamic> raw) {
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
    return _OfflineCacheMeta(
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

final offlineJsonCacheStoreProvider = Provider<OfflineJsonCacheStore>(
  (_) => SharedPrefsOfflineJsonCacheStore.instance,
);
