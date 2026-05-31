import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug-only per-token palette overrides.
///
/// Persists as `palette.override.<token>` keys → 32-bit ARGB ints. The theme
/// builder consumes the resolved map via `AppPalette.applyOverrides`, so any
/// change here forces a MaterialApp rebuild with the new AppPalette.
///
/// The reserved `seed` key (see [PaletteTokens.seed]) is not a semantic token —
/// `main.dart` pulls it out of the map and uses it as the `ColorScheme.fromSeed`
/// seed directly. `AppPalette.applyOverrides` silently drops unknown keys, so
/// the sentinel survives round-tripping without needing a separate store.
class PaletteOverridesNotifier extends AsyncNotifier<Map<String, Color>> {
  static const _prefix = 'palette.override.';

  @override
  Future<Map<String, Color>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, Color>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(_prefix)) continue;
      final raw = prefs.get(k);
      if (raw is int) {
        out[k.substring(_prefix.length)] = Color(raw);
      }
    }
    return out;
  }

  Future<void> setOverride(String token, Color color) async {
    final current = Map<String, Color>.from(state.asData?.value ?? const {});
    current[token] = color;
    state = AsyncValue.data(current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$token', _argb(color));
  }

  Future<void> clearOverride(String token) async {
    final current = Map<String, Color>.from(state.asData?.value ?? const {});
    current.remove(token);
    state = AsyncValue.data(current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$token');
  }

  Future<void> clearAll() async {
    state = const AsyncValue.data({});
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  // Flutter dev channel deprecated `Color.value` in favour of the component
  // accessors, so rebuild the 32-bit ARGB explicitly.
  static int _argb(Color c) {
    int ch(double v) => (v * 255.0).round().clamp(0, 255);
    return (ch(c.a) << 24) | (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  }
}

final paletteOverridesProvider =
    AsyncNotifierProvider<PaletteOverridesNotifier, Map<String, Color>>(
  PaletteOverridesNotifier.new,
);
