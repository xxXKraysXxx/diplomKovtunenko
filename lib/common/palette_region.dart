import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show scaffoldMessengerKey;
import '../theme/app_palette.dart';

/// Session-lived toggle; resets on app restart — this is a debug aid, not a
/// persistent user preference. Riverpod 3 dropped `StateProvider`, so this is
/// a tiny boolean [Notifier] wrapper.
class PaletteInspectorNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
  void toggle() => state = !state;
}

final paletteInspectorProvider =
    NotifierProvider<PaletteInspectorNotifier, bool>(
  PaletteInspectorNotifier.new,
);

/// Wraps a widget so that — while the inspector is on — right-click / long-press
/// reveals which [AppPalette] token drove the colour of this region.
///
/// When the inspector is off this widget is a pure passthrough and does not
/// install any gesture recognisers.
class PaletteRegion extends ConsumerWidget {
  const PaletteRegion({
    required this.token,
    required this.child,
    super.key,
  });

  final String token;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(paletteInspectorProvider);
    if (!on) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (_) => _report(context),
      onLongPress: () => _report(context),
      child: child,
    );
  }

  void _report(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = palette.byToken(token);
    final hex = _hex(color);
    final messenger = scaffoldMessengerKey.currentState ??
        ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('$token\n$hex'),
        action: SnackBarAction(
          label: hex,
          onPressed: () => Clipboard.setData(ClipboardData(text: hex)),
        ),
      ),
    );
  }
}

String _hex(Color c) {
  int ch(double v) => (v * 255.0).round().clamp(0, 255);
  String hh(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${hh(ch(c.r))}${hh(ch(c.g))}${hh(ch(c.b))}';
}
