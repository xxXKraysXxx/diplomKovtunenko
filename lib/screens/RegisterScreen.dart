import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/raspisanie_repository.dart';
import '../common/auth_error.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/raspisanie.dart';
import '../state/auth.dart';
import '../state/gate.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  int? _groupId;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final login = _loginCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _passConfirmCtrl.text;
    if (login.isEmpty) {
      setState(() => _error = l10n.registerLoginEmpty);
      return;
    }
    if (password.length < 6) {
      setState(() => _error = l10n.registerPasswordTooShort);
      return;
    }
    if (password != confirm) {
      setState(() => _error = l10n.registerPasswordsMismatch);
      return;
    }
    if (_groupId == null) {
      setState(() => _error = l10n.registerGroupRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .registerStudent(login, password, _groupId!);
      await ref.read(gateSeenProvider.notifier).markSeen();
      if (mounted) context.go('/schedule');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeAuthError(l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final groupsAsync = ref.watch(allGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registerTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _loginCtrl,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: l10n.loginLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  enabled: !_busy,
                  obscureText: _obscure,
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
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passConfirmCtrl,
                  enabled: !_busy,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: l10n.registerRepeatPassword,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _GroupPicker(
                  async: groupsAsync,
                  selected: _groupId,
                  enabled: !_busy,
                  onChanged: (id) => setState(() => _groupId = id),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.registerSubmit,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => context.go('/login'),
                  child: Text(l10n.registerHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({
    required this.async,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });
  final AsyncValue<List<NamedRef>> async;
  final int? selected;
  final bool enabled;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return async.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.registerGroupLabel,
          border: const OutlineInputBorder(),
        ),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => Text(
        l10n.registerGroupsLoadError(e.toString()),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (items) => DropdownButtonFormField<int>(
        value: selected,
        isExpanded: true,
        onChanged: enabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: l10n.registerGroupLabel,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final g in items)
            DropdownMenuItem(value: g.id, child: Text(g.name)),
        ],
      ),
    );
  }
}
