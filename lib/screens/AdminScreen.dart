import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/graphql_config.dart';
import '../api/queries.dart';
import '../api/raspisanie_repository.dart';
import '../common/accent_color.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_user.dart';
import '../models/raspisanie.dart';
import '../models/server_activity.dart';
import '../state/auth.dart';

final _usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  // Depend on authEpoch so cache flushes on login/logout.
  ref.watch(authEpochProvider);
  final client = ref.watch(graphqlClientProvider);
  final r = await client.query(QueryOptions(
    document: gql(usersQuery),
    fetchPolicy: FetchPolicy.networkOnly,
  ));
  if (r.hasException) throw r.exception!;
  final list = (r.data?['users'] as List?) ?? const [];
  return list.cast<Map<String, dynamic>>().map(AppUser.fromJson).toList();
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/schedule');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/schedule'),
          ),
          title: Text(l10n.adminTitle),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [
              Tab(text: l10n.adminTabUsers),
              Tab(text: l10n.adminTabCreateTeacher),
              Tab(text: l10n.adminTabCreateAdmin),
              Tab(text: l10n.adminTabPushRights),
              Tab(text: l10n.adminTabActivity),
              Tab(text: l10n.adminTabSettings),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            _UsersTab(),
            _CreateTeacherTab(),
            _CreateAdminTab(),
            _PushPermissionsTab(),
            _ActivityTab(),
            _AppSettingsTab(),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab>
    with SingleTickerProviderStateMixin {
  // Order matches the role sub-tabs below; default landing tab = students (index 2).
  static const _roleOrder = [UserRole.admin, UserRole.teacher, UserRole.student];
  late final TabController _roleTabs =
      TabController(length: _roleOrder.length, vsync: this, initialIndex: 2);
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _roleTabs.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _searchQuery = v.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usersAsync = ref.watch(_usersProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l10n.adminSearchLogin,
              border: const OutlineInputBorder(),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
            ),
          ),
        ),
        TabBar(
          controller: _roleTabs,
          tabs: [
            Tab(text: l10n.adminRoleAdmins),
            Tab(text: l10n.adminRoleTeachers),
            Tab(text: l10n.adminRoleStudents),
          ],
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBox(context, e),
            data: (users) => TabBarView(
              controller: _roleTabs,
              children: [
                for (final role in _roleOrder)
                  _UsersList(
                    users: _filter(users, role, _searchQuery),
                    searchActive: _searchQuery.isNotEmpty,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<AppUser> _filter(List<AppUser> all, UserRole role, String q) {
    final scoped = all.where((u) => u.role == role);
    if (q.isEmpty) return scoped.toList();
    return scoped.where((u) => u.login.toLowerCase().contains(q)).toList();
  }
}

class _UsersList extends ConsumerWidget {
  const _UsersList({required this.users, required this.searchActive});
  final List<AppUser> users;
  final bool searchActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider);
    final groupsAsync = ref.watch(allGroupsProvider);
    final teachersAsync = ref.watch(allTeachersProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_usersProvider);
        ref.invalidate(allGroupsProvider);
        ref.invalidate(allTeachersProvider);
      },
      child: users.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    searchActive ? l10n.commonNothingFound : l10n.adminUsersEmpty,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            )
          : ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                final isMe = me?.id == u.id;
                return _UserRow(
                  user: u,
                  isMe: isMe,
                  groups: groupsAsync.asData?.value ?? const <NamedRef>[],
                  teachers: teachersAsync.asData?.value ?? const <NamedRef>[],
                );
              },
            ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({
    required this.user,
    required this.isMe,
    required this.groups,
    required this.teachers,
  });
  final AppUser user;
  final bool isMe;
  final List<NamedRef> groups;
  final List<NamedRef> teachers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final linkedLabel = _linkedEntityLabel(l10n);
    final linkedDeleted = _isLinkedDeleted();
    final linkedWidget = linkedLabel == null
        ? const Text('—', style: TextStyle(color: Colors.grey))
        : Tooltip(
            message: linkedDeleted ? l10n.adminRecordDeleted : '',
            child: Text(
              linkedLabel,
              style: linkedDeleted
                  ? const TextStyle(color: Colors.grey)
                  : null,
            ),
          );

    final accentColor = parseHexColor(user.accentColor);
    return ListTile(
      leading: accentColor != null
          ? Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            )
          : const SizedBox(width: 12),
      title: Row(
        children: [
          Expanded(child: Text(user.login)),
          if (isMe) Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Chip(label: Text(l10n.adminSelfMarker), visualDensity: VisualDensity.compact),
          ),
        ],
      ),
      subtitle: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 13),
        child: Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(roleLabel(l10n, user.role)),
            const Text('·'),
            linkedWidget,
            if (user.storage != null) ...[
              const Text('·'),
              Text(_storageLabel(l10n, user.storage!),
                  style: const TextStyle(color: Colors.grey)),
            ],
            const Text('·'),
            Text(l10n.adminLastActive(user.lastActivityAt),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: l10n.adminActions,
        icon: const Icon(Icons.more_vert),
        onSelected: (v) {
          switch (v) {
            case 'reset':
              _openResetDialog(context, ref);
              break;
            case 'delete':
              _confirmDelete(context, ref);
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'reset',
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: Text(l10n.adminResetPassword),
              dense: true,
            ),
          ),
          if (!isMe)
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(l10n.commonDelete),
                dense: true,
              ),
            ),
        ],
      ),
    );
  }

  String? _linkedEntityLabel(AppLocalizations l10n) {
    switch (user.role) {
      case UserRole.student:
        if (user.groupId == null) return null;
        final hit = groups.where((g) => g.id == user.groupId).toList();
        return hit.isEmpty ? '—' : l10n.adminGroupPrefix(hit.first.name);
      case UserRole.teacher:
        if (user.teacherId == null) return null;
        final hit = teachers.where((t) => t.id == user.teacherId).toList();
        return hit.isEmpty ? '—' : hit.first.name;
      case UserRole.admin:
      case UserRole.system:
        return null;
    }
  }

  bool _isLinkedDeleted() {
    switch (user.role) {
      case UserRole.student:
        return user.groupId != null &&
            !groups.any((g) => g.id == user.groupId);
      case UserRole.teacher:
        return user.teacherId != null &&
            !teachers.any((t) => t.id == user.teacherId);
      case UserRole.admin:
      case UserRole.system:
        return false;
    }
  }

  Future<void> _openResetDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    if (isMe) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.adminResetOwnConfirmTitle),
          content: Text(l10n.adminResetOwnConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonContinue),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        user: user,
        onSuccess: () => ref.invalidate(_usersProvider),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.adminDeleteUserConfirmTitle),
        content: Text(l10n.adminDeleteUserConfirmBody(
            user.login, roleLabel(l10n, user.role))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(deleteUserMutation),
      variables: {'id': user.id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonErrorWith(_errMsg(l10n, r.exception!)))),
        );
      }
      return;
    }
    ref.invalidate(_usersProvider);
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({required this.user, required this.onSuccess});
  final AppUser user;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final p = _pass.text;
    final c = _confirm.text;
    if (p.length < 6) {
      setState(() => _error = l10n.registerPasswordTooShort);
      return;
    }
    if (p != c) {
      setState(() => _error = l10n.registerPasswordsMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(adminResetPasswordMutation),
      variables: {'userId': widget.user.id, 'newPassword': p},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (r.hasException) {
      setState(() {
        _busy = false;
        _error = _errMsg(l10n, r.exception!);
      });
      return;
    }
    widget.onSuccess();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminPasswordUpdatedFor(widget.user.login))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminResetPasswordFor(widget.user.login)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pass,
              enabled: !_busy,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.adminNewPassword,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              enabled: !_busy,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.adminConfirmPassword,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _CreateTeacherTab extends ConsumerStatefulWidget {
  const _CreateTeacherTab();
  @override
  ConsumerState<_CreateTeacherTab> createState() => _CreateTeacherTabState();
}

class _CreateTeacherTabState extends ConsumerState<_CreateTeacherTab> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  int? _teacherId;
  bool _busy = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _login.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final login = _login.text.trim();
    final password = _pass.text;
    if (login.isEmpty || password.length < 6 || _teacherId == null) {
      setState(() => _error = l10n.adminCreateTeacherFormHint);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(createTeacherMutation),
      variables: {
        'login': login,
        'password': password,
        'teacherId': _teacherId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (r.hasException) {
      setState(() {
        _busy = false;
        _error = _errMsg(l10n, r.exception!);
      });
      return;
    }
    ref.invalidate(_usersProvider);
    setState(() {
      _busy = false;
      _ok = l10n.adminCreatedNotice(login);
      _login.clear();
      _pass.clear();
      _teacherId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final teachers = ref.watch(allTeachersProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _login,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l10n.adminLoginField,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            enabled: !_busy,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.adminPasswordField,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          teachers.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(l10n.adminLoadError(e.toString())),
            data: (items) => DropdownButtonFormField<int>(
              value: _teacherId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.adminTeacherField,
                border: const OutlineInputBorder(),
              ),
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _teacherId = v),
              items: [
                for (final t in items)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_ok != null) ...[
            const SizedBox(height: 12),
            Text(_ok!, style: const TextStyle(color: Colors.green)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.adminCreateTeacherTitle),
          ),
        ],
      ),
    );
  }
}

class _CreateAdminTab extends ConsumerStatefulWidget {
  const _CreateAdminTab();
  @override
  ConsumerState<_CreateAdminTab> createState() => _CreateAdminTabState();
}

class _CreateAdminTabState extends ConsumerState<_CreateAdminTab> {
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _expanded = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _login.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final login = _login.text.trim();
    final password = _pass.text;
    if (login.isEmpty || password.length < 6) {
      setState(() => _error = l10n.adminCreateAdminRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(createAdminMutation),
      variables: {'login': login, 'password': password},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (r.hasException) {
      setState(() {
        _busy = false;
        _error = _errMsg(l10n, r.exception!);
      });
      return;
    }
    ref.invalidate(_usersProvider);
    setState(() {
      _busy = false;
      _ok = l10n.adminCreateAdminCreated(login);
      _login.clear();
      _pass.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ExpansionTile(
              initiallyExpanded: _expanded,
              onExpansionChanged: (v) => setState(() => _expanded = v),
              title: Text(l10n.adminCreateAdminTitle),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                TextField(
                  controller: _login,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: l10n.adminLoginField,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.adminPasswordField,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 12),
                  Text(_ok!, style: const TextStyle(color: Colors.green)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.adminCreateAdminTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PushPermissionsTab extends ConsumerWidget {
  const _PushPermissionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usersAsync = ref.watch(_usersProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            l10n.adminPushHint,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBox(context, e),
            data: (users) {
              final teachers =
                  users.where((u) => u.role == UserRole.teacher).toList();
              if (teachers.isEmpty) {
                return Center(
                  child: Text(l10n.adminNoTeachers),
                );
              }
              return ListView.separated(
                itemCount: teachers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = teachers[i];
                  return _PushRow(user: u);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PushRow extends ConsumerStatefulWidget {
  const _PushRow({required this.user});
  final AppUser user;
  @override
  ConsumerState<_PushRow> createState() => _PushRowState();
}

class _PushRowState extends ConsumerState<_PushRow> {
  late bool _canPush = widget.user.canPush;
  late bool _canGlobal = widget.user.canBroadcastGlobally;
  bool _busyPush = false;
  bool _busyGlobal = false;

  String _teacherSubtitle(AppLocalizations l10n, List<NamedRef> teachers) {
    final tid = widget.user.teacherId;
    if (tid == null) return l10n.adminTeacherUnlinked;
    final hit = teachers.where((t) => t.id == tid).toList();
    if (hit.isEmpty) return l10n.adminTeacherId('$tid');
    return hit.first.name;
  }

  Future<void> _togglePush(bool v) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _canPush = v;
      _busyPush = true;
    });
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(setTeacherPushMutation),
      variables: {
        'teacherUserId': widget.user.id,
        'canPush': v,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (r.hasException) {
      setState(() {
        _canPush = !v;
        _busyPush = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonErrorWith(_errMsg(l10n, r.exception!)))),
      );
      return;
    }
    setState(() {
      _busyPush = false;
      if (!v) _canGlobal = false;
    });
    ref.invalidate(_usersProvider);
  }

  Future<void> _toggleGlobal(bool v) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _canGlobal = v;
      _busyGlobal = true;
    });
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(setUserCanBroadcastGloballyMutation),
      variables: {
        'userId': widget.user.id,
        'enabled': v,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (r.hasException) {
      setState(() {
        _canGlobal = !v;
        _busyGlobal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonErrorWith(_errMsg(l10n, r.exception!)))),
      );
      return;
    }
    setState(() => _busyGlobal = false);
    ref.invalidate(_usersProvider);
  }

  Widget _switch(bool value, bool busy, ValueChanged<bool>? onChanged) {
    return busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Switch(value: value, onChanged: onChanged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final u = widget.user;
    final teachersAsync = ref.watch(allTeachersProvider);
    final subtitle = teachersAsync.maybeWhen(
      data: (teachers) => _teacherSubtitle(l10n, teachers),
      orElse: () => l10n.adminTeacherId('${u.teacherId ?? "?"}'),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(u.login,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(l10n.adminCanPushLabel)),
              _switch(_canPush, _busyPush, _togglePush),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text(l10n.adminCanBroadcastGloballyLabel)),
              _switch(
                _canGlobal,
                _busyGlobal,
                _canPush ? _toggleGlobal : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppSettingsTab extends ConsumerStatefulWidget {
  const _AppSettingsTab();
  @override
  ConsumerState<_AppSettingsTab> createState() => _AppSettingsTabState();
}

class _AppSettingsTabState extends ConsumerState<_AppSettingsTab> {
  bool _busy = false;

  Future<void> _runNewsScrape() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(runNewsScrapeMutation),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonErrorWith(_errMsg(l10n, r.exception!)))),
      );
      return;
    }
    final accepted = r.data?['runNewsScrape'] as bool? ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(accepted
            ? l10n.adminNewsScrapeAccepted
            : l10n.adminNewsScrapeBusy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminNewsScrapeTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.adminNewsScrapeHint,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _runNewsScrape,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(l10n.adminNewsScrapeButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _storageLabel(AppLocalizations l10n, UserStorage s) {
  final notes = formatBytes(l10n, s.noteBytes);
  final total = formatBytes(l10n, s.totalBytes);
  if (s.noteBytes == 0 && s.notificationBytes == 0 && s.deviceTokenCount == 0) {
    return l10n.adminNoData;
  }
  if (s.notificationBytes == 0) {
    return l10n.adminStorageNotes(notes);
  }
  return l10n.adminStorageTotal(total);
}

final _serverActivityProvider =
    FutureProvider.autoDispose<ServerActivitySnapshot>((ref) async {
  ref.watch(authEpochProvider);
  final client = ref.watch(graphqlClientProvider);
  final r = await client.query(QueryOptions(
    document: gql(serverActivityQuery),
    variables: const {'limit': 100},
    fetchPolicy: FetchPolicy.networkOnly,
  ));
  if (r.hasException) throw r.exception!;
  final data = r.data?['serverActivity'] as Map<String, dynamic>?;
  if (data == null) {
    throw Exception('serverActivity missing');
  }
  return ServerActivitySnapshot.fromJson(data);
});

class _ActivityTab extends ConsumerStatefulWidget {
  const _ActivityTab();
  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  Timer? _poll;
  ActivityFilter _filter = ActivityFilter.all;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(_serverActivityProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snap = ref.watch(_serverActivityProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_serverActivityProvider),
      child: snap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [_errorBox(context, e)],
        ),
        data: (s) {
          final filtered = s.recentEvents
              .where((e) => matchesFilter(e.action, _filter))
              .toList();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _StatsRow(snap: s),
              const Divider(height: 1),
              _FilterChipRow(
                active: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const Divider(height: 1),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(l10n.adminActivityEmpty,
                        style: const TextStyle(color: Colors.grey)),
                  ),
                )
              else
                for (final e in filtered) _EventRow(event: e),
            ],
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.snap});
  final ServerActivitySnapshot snap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatsCard(
            title: l10n.adminActivity7d,
            items: [
              (l10n.adminActivityRegistrations, snap.registrations),
              (l10n.adminActivityFailedLogins, snap.failedLogins),
            ],
          ),
          const SizedBox(height: 8),
          _StatsCard(
            title: l10n.adminActivity30d,
            items: [
              (l10n.adminActivityPasswordResets, snap.passwordResets),
              (l10n.adminActivitySentNotifications, snap.notificationsSent),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.title, required this.items});
  final String title;
  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final it in items)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${it.$2}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text(it.$1, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.active, required this.onChanged});
  final ActivityFilter active;
  final ValueChanged<ActivityFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final f in ActivityFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filterLabel(l10n, f)),
                selected: active == f,
                onSelected: (_) => onChanged(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ts = _formatTime(event.createdAt);
    final who = event.userLogin ?? (event.userId == null ? '—' : '#${event.userId}');
    final detailSummary = _summarizeDetails(event.details);
    return ListTile(
      dense: true,
      title: Text(actionLabel(l10n, event.action),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(ts, style: const TextStyle(color: Colors.grey)),
            Text('·', style: TextStyle(color: Colors.grey.shade400)),
            Text(who),
            if (detailSummary != null) ...[
              Text('·', style: TextStyle(color: Colors.grey.shade400)),
              Text(detailSummary, style: const TextStyle(color: Colors.grey)),
            ],
            if (event.ip != null && event.ip!.isNotEmpty) ...[
              Text('·', style: TextStyle(color: Colors.grey.shade400)),
              Text(event.ip!, style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '$y-$m-$day $hh:$mm';
    } catch (_) {
      return iso;
    }
  }

  String? _summarizeDetails(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json);
      if (m is! Map) return null;
      final bits = <String>[];
      if (m['login'] != null) bits.add(m['login'].toString());
      if (m['targetLogin'] != null) bits.add('→ ${m['targetLogin']}');
      if (m['scope'] != null) bits.add('scope=${m['scope']}');
      if (m['reason'] != null) bits.add(m['reason'].toString());
      if (m['canPush'] != null) bits.add('canPush=${m['canPush']}');
      if (bits.isEmpty) return null;
      return bits.join(', ');
    } catch (_) {
      return null;
    }
  }
}

Widget _errorBox(BuildContext context, Object e) {
  final l10n = AppLocalizations.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        l10n.commonErrorWith(e.toString()),
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}

String _errMsg(AppLocalizations l10n, OperationException e) {
  if (e.graphqlErrors.isNotEmpty) return e.graphqlErrors.first.message;
  return e.linkException?.toString() ?? l10n.commonError;
}
