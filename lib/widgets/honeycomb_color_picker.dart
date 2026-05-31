import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';

/// Opens a color picker dialog.
/// Returns the picked [Color] or null if cancelled.
Future<Color?> showHoneycombColorPicker({
  required BuildContext context,
  Color? current,
}) async {
  final l10n = AppLocalizations.of(context);
  Color picked = current ?? const Color(0xFFEF4444);
  return showDialog<Color>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final argbText = _argbLabel(picked);
        return AlertDialog(
          title: Text(l10n.colorPickerTitle),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColorPicker(
                    color: picked,
                    onColorChanged: (c) => setState(() => picked = c),
                    enableShadesSelection: true,
                    enableTonalPalette: false,
                    pickersEnabled: const {
                      ColorPickerType.primary: true,
                      ColorPickerType.accent: false,
                      ColorPickerType.wheel: true,
                      ColorPickerType.both: false,
                      ColorPickerType.bw: false,
                      ColorPickerType.custom: false,
                      ColorPickerType.customSecondary: false,
                    },
                    pickerTypeLabels: {
                      ColorPickerType.primary: l10n.colorPickerPrimary,
                      ColorPickerType.wheel: l10n.colorPickerWheel,
                    },
                    width: 38,
                    height: 38,
                    spacing: 4,
                    runSpacing: 4,
                    borderRadius: 19,
                    subheading: Text(
                      l10n.colorPickerShade,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    wheelSubheading: Text(
                      l10n.colorPickerCustom,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    showColorCode: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: picked,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          argbText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.commonCopy,
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: argbText),
                          );
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(l10n.colorPickerCopied),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(picked),
              child: Text(l10n.commonApply),
            ),
          ],
        );
      },
    ),
  );
}

int _colorChannel(double v) => (v * 255.0).round().clamp(0, 255);

String _argbLabel(Color c) {
  final a = _colorChannel(c.a).toRadixString(16).padLeft(2, '0').toUpperCase();
  final r = _colorChannel(c.r).toRadixString(16).padLeft(2, '0').toUpperCase();
  final g = _colorChannel(c.g).toRadixString(16).padLeft(2, '0').toUpperCase();
  final b = _colorChannel(c.b).toRadixString(16).padLeft(2, '0').toUpperCase();
  return 'A:$a R:$r G:$g B:$b';
}
