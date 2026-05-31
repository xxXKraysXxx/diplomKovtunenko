import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/raspisanie_repository.dart';
import '../common/embed_bridge.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/raspisanie.dart';
import '../state/auth.dart';
import '../state/gate.dart';
import '../state/schedule_filters.dart';
import '../state/settings.dart';
import 'ScheduleScreen.dart';

class EmbedScheduleScreen extends ConsumerStatefulWidget {
  const EmbedScheduleScreen({super.key});

  @override
  ConsumerState<EmbedScheduleScreen> createState() =>
      _EmbedScheduleScreenState();
}

class _EmbedScheduleScreenState extends ConsumerState<EmbedScheduleScreen> {
  bool _queryParamsApplied = false;

  @override
  void initState() {
    super.initState();
    // Mark gate seen so the router doesn't try to redirect embed -> /gate.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(gateSeenProvider.notifier).markSeen();
      } catch (_) {}
    });
  }

  void _applyQueryParamsOnce(GoRouterState state) {
    if (_queryParamsApplied) return;
    _queryParamsApplied = true;

    final theme = state.uri.queryParameters['theme']?.toLowerCase();
    if (theme == 'dark' || theme == 'light' || theme == 'system') {
      final mode = switch (theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      // Defer past build so provider modification doesn't blow up.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(themeModeProvider.notifier).set(mode);
      });
    }

    final date = state.uri.queryParameters['date'];
    if (date != null && date.isNotEmpty) {
      try {
        final parsed = DateTime.parse(date);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(selectedDateProvider.notifier)
              .set(DateTime(parsed.year, parsed.month, parsed.day));
          final firstOfMonth = DateTime(parsed.year, parsed.month, 1);
          ref.read(displayedMonthProvider.notifier).set(firstOfMonth);
          ref.read(stripVisibleMonthProvider.notifier).set(firstOfMonth);
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final routerState = GoRouterState.of(context);
    _applyQueryParamsOnce(routerState);

    final async = ref.watch(monthRaspisanieProvider);
    final cached = ref.watch(lastMonthEntriesProvider);
    final data = async.asData?.value ?? cached ?? const <RaspisanieEntry>[];
    final authed =
        ref.watch(authProvider).asData?.value.isAuthenticated ?? false;

    return Scaffold(
      body: _EmbedHeightProbe(
        child: async.isLoading && cached == null
            ? const Center(child: CircularProgressIndicator())
            : ScheduleBodyView(
                entries: data,
                embed: true,
                filterTrailing: authed
                    ? null
                    : _LoginChip(onTap: () => _openLoginDialog(context, ref)),
              ),
      ),
    );
  }
}

/// Measures its child's natural (intrinsic) height and forwards it to the
/// outer page via postMessage. Flutter web renders into a shadow-DOM canvas
/// whose size isn't visible to DOM scrollHeight, so Dart is the only
/// reliable source of truth for how tall the iframe should be.
class _EmbedHeightProbe extends SingleChildRenderObjectWidget {
  const _EmbedHeightProbe({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EmbedHeightProbeRender();
}

class _EmbedHeightProbeRender extends RenderProxyBox {
  int _lastPosted = -1;

  @override
  void performLayout() {
    final c = constraints;
    final relaxed = BoxConstraints(
      minWidth: c.minWidth,
      maxWidth: c.maxWidth,
      minHeight: 0,
      maxHeight: double.infinity,
    );
    child!.layout(relaxed, parentUsesSize: true);
    final childSize = child!.size;
    // Satisfy parent's constraints; overflow past the current canvas is
    // acceptable because the post below grows the iframe, which grows the
    // Flutter view via `min-height: 100vh`.
    size = c.constrain(Size(childSize.width, childSize.height));
    final h = childSize.height.ceil();
    if (h != _lastPosted && h > 0) {
      _lastPosted = h;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        postEmbedHeight(h);
      });
    }
  }
}

class _LoginChip extends StatelessWidget {
  const _LoginChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.login, size: 16, color: scheme.onPrimary),
              const SizedBox(width: 6),
              Text(
                l10n.loginSubmit,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openLoginDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _EmbedLoginDialog(),
  );
}

class _EmbedLoginDialog extends ConsumerStatefulWidget {
  const _EmbedLoginDialog();
  @override
  ConsumerState<_EmbedLoginDialog> createState() => _EmbedLoginDialogState();
}

class _EmbedLoginDialogState extends ConsumerState<_EmbedLoginDialog> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final login = _loginCtrl.text.trim();
    final password = _passCtrl.text;
    if (login.isEmpty || password.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).authBadCredentials);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(login, password);
      // Force the schedule to re-fetch with the user's default filter.
      ref.invalidate(monthRaspisanieProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.loginTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _loginCtrl,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.loginLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              enabled: !_busy,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.loginContinueAsGuest),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.loginSubmit),
        ),
      ],
    );
  }
}
