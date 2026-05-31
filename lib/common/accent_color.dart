import 'package:flutter/material.dart';

const accentColorPalette = <String>[
  '#ef4444', // red
  '#f97316', // orange
  '#eab308', // yellow
  '#22c55e', // green
  '#14b8a6', // teal
  '#06b6d4', // cyan
  '#3b82f6', // blue
  '#6366f1', // indigo
  '#a855f7', // purple
  '#ec4899', // pink
  '#78716c', // stone
  '#0f172a', // slate-900
];

/// Parse "#rrggbb" to Color. Returns null when the input is not a valid
/// 6-digit hex color.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

/// Resolve a sender's accent color, falling back to the red default.
Color accentColorOf(String? hex, {required bool isDark}) {
  return parseHexColor(hex) ??
      (isDark ? Colors.red.shade300 : Colors.red.shade400);
}
