import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the current auth token in memory and persists it.
///
/// On supported platforms uses [FlutterSecureStorage]. On Flutter web it
/// falls back to [SharedPreferences] since secure storage on web is just
/// localStorage anyway — no meaningful security distinction.
class TokenStore {
  TokenStore._();

  /// Test-only constructor: bypasses real secure storage / SharedPreferences
  /// so unit tests can inject a token without booting the platform plugins.
  /// Production code must continue to use [TokenStore.instance].
  @visibleForTesting
  TokenStore.forTesting({String? initial})
      : _cache = initial,
        _loaded = true;

  static const _key = 'auth_token_v1';
  static const _secure = FlutterSecureStorage();

  String? _cache;
  bool _loaded = false;

  static final TokenStore instance = TokenStore._();

  String? get cached => _cache;

  Future<String?> load() async {
    if (_loaded) return _cache;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        _cache = prefs.getString(_key);
      } else {
        _cache = await _secure.read(key: _key);
      }
    } catch (_) {
      _cache = null;
    }
    _loaded = true;
    return _cache;
  }

  Future<void> save(String token) async {
    _cache = token;
    _loaded = true;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, token);
      } else {
        await _secure.write(key: _key, value: token);
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
      } else {
        await _secure.delete(key: _key);
      }
    } catch (_) {}
  }
}

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore.instance);
