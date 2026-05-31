import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/auth_error.dart';
import '../common/top_banner.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/auth.dart';
import '../state/gate.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
    final l10n = AppLocalizations.of(context);
    final login = _loginCtrl.text.trim();
    final password = _passCtrl.text;
    if (login.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.authBadCredentials);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(login, password);
      await ref.read(gateSeenProvider.notifier).markSeen();
      if (mounted) context.go('/schedule');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = null;
        });
        if (isConnectionLike(e)) {
          TopBanner.showError(l10n.authConnectionTimeout);
        } else {
          setState(() => _error = describeAuthError(l10n, e));
        }
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _busy = true);
    await ref.read(gateSeenProvider.notifier).markSeen();
    await ref.read(guestModeChosenProvider.notifier).markChosen();
    if (context.mounted) context.go('/schedule');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.loginTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _loginCtrl,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: l10n.loginLabel,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  enabled: !_busy,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    border: const OutlineInputBorder(),
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
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.loginSubmit,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : _continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(l10n.loginContinueAsGuest),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => context.go('/register'),
                    child: Text(
                      l10n.loginRegisterHint,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
