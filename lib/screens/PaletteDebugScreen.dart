import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/palette_region.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/palette_overrides.dart';
import '../theme/app_palette.dart';
import '../widgets/honeycomb_color_picker.dart';

class PaletteDebugScreen extends ConsumerWidget {
  const PaletteDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final overrides =
        ref.watch(paletteOverridesProvider).asData?.value ?? const {};
    final inspectorOn = ref.watch(paletteInspectorProvider);
    final seedOverride = overrides[PaletteTokens.seed];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paletteDebugTitle),
        actions: [
          TextButton.icon(
            onPressed: overrides.isEmpty
                ? null
                : () async {
                    await ref
                        .read(paletteOverridesProvider.notifier)
                        .clearAll();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.paletteDebugResetDone)),
                    );
                  },
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(l10n.paletteDebugReset),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(l10n.paletteDebugInspectorLabel),
            value: inspectorOn,
            onChanged: (v) =>
                ref.read(paletteInspectorProvider.notifier).set(v),
          ),
          const Divider(height: 12),
          _SeedRow(
            seedColor: seedOverride ?? scheme.primary,
            overridden: seedOverride != null,
          ),
          const Divider(height: 12),
          for (final token in PaletteTokens.all)
            _TokenRow(
              token: token,
              color: palette.byToken(token),
              overridden: overrides.containsKey(token),
            ),
        ],
      ),
    );
  }
}

class _SeedRow extends ConsumerWidget {
  const _SeedRow({required this.seedColor, required this.overridden});
  final Color seedColor;
  final bool overridden;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked =
        await showHoneycombColorPicker(context: context, current: seedColor);
    if (picked == null) return;
    await ref
        .read(paletteOverridesProvider.notifier)
        .setOverride(PaletteTokens.seed, picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: GestureDetector(
        onTap: () => _pick(context, ref),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: seedColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
        ),
      ),
      title: Text(
        l10n.paletteDebugSeedLabel,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        _hexLabel(seedColor),
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
      trailing: overridden
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: l10n.paletteDebugClearOverrideTooltip,
              onPressed: () => ref
                  .read(paletteOverridesProvider.notifier)
                  .clearOverride(PaletteTokens.seed),
            )
          : const SizedBox(width: 40),
      onTap: () => _pick(context, ref),
    );
  }
}

class _TokenRow extends ConsumerWidget {
  const _TokenRow({
    required this.token,
    required this.color,
    required this.overridden,
  });
  final String token;
  final Color color;
  final bool overridden;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await showHoneycombColorPicker(
      context: context,
      current: color,
    );
    if (picked == null) return;
    await ref
        .read(paletteOverridesProvider.notifier)
        .setOverride(token, picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _pick(context, ref),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.outlineVariant, width: 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                token,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _hexLabel(color),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(
              width: 36,
              height: 32,
              child: overridden
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.paletteDebugClearOverrideTooltip,
                      onPressed: () => ref
                          .read(paletteOverridesProvider.notifier)
                          .clearOverride(token),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

String _hexLabel(Color c) {
  int ch(double v) => (v * 255.0).round().clamp(0, 255);
  String hh(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${hh(ch(c.r))}${hh(ch(c.g))}${hh(ch(c.b))}';
}
