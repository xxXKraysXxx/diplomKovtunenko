import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/raspisanie_repository.dart';
import '../common/accent_color.dart';
import '../theme/app_palette.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_user.dart';
import '../models/notification_item.dart';
import '../models/raspisanie.dart';
import '../state/auth.dart';
import '../state/notifications.dart';
import '../state/settings.dart';

String _monthGen(AppLocalizations l10n, int month) {
  switch (month) {
    case 1: return l10n.monthGenJan;
    case 2: return l10n.monthGenFeb;
    case 3: return l10n.monthGenMar;
    case 4: return l10n.monthGenApr;
    case 5: return l10n.monthGenMay;
    case 6: return l10n.monthGenJun;
    case 7: return l10n.monthGenJul;
    case 8: return l10n.monthGenAug;
    case 9: return l10n.monthGenSep;
    case 10: return l10n.monthGenOct;
    case 11: return l10n.monthGenNov;
    default: return l10n.monthGenDec;
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoMarkReadOnOpen();
    });
  }

  void _autoMarkReadOnOpen() {
    unawaited(ref.read(notificationsProvider.notifier).autoMarkAllRead());
    unawaited(() async {
      try {
        await ref.read(notificationsProvider.future);
        if (!mounted) return;
        await ref.read(notificationsProvider.notifier).autoMarkAllRead();
      } catch (_) {}
    }());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen<AsyncValue<List<NotificationItem>>>(notificationsProvider,
        (_, next) {
      next.whenData((items) {
        if (items.any((n) => !n.isRead)) {
          unawaited(ref.read(notificationsProvider.notifier).autoMarkAllRead());
        }
      });
    });
    final async = ref.watch(notificationsProvider);
    final user = ref.watch(currentUserProvider);
    final canCompose = user != null &&
        (user.role == UserRole.admin ||
            (user.role == UserRole.teacher && user.canPush));
    final isAdmin = user?.role == UserRole.admin;
    final adminShowGroup = ref
            .watch(adminShowGroupNotificationsProvider)
            .asData
            ?.value ??
        false;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(
          l10n.notificationsTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: adminShowGroup
                  ? l10n.notificationsAdminShowAllOn
                  : l10n.notificationsAdminShowAllOff,
              icon: Icon(
                adminShowGroup ? Icons.groups : Icons.public,
              ),
              onPressed: () => ref
                  .read(adminShowGroupNotificationsProvider.notifier)
                  .set(!adminShowGroup),
            ),
        ],
      ),
      floatingActionButton: canCompose
          ? FloatingActionButton.extended(
              onPressed: () => _openCompose(context, ref, user),
              icon: const Icon(Icons.campaign),
              label: Text(l10n.notificationsSend),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) {
          // Admins by default only see global notifications — opt-in toggle
          // surfaces per-group blasts again. Non-admins always see their own
          // group's items, so the filter is a no-op for them.
          final visible = (isAdmin && !adminShowGroup)
              ? items
                  .where((i) => i.scope == NotificationScope.global)
                  .toList(growable: false)
              : items;
          if (visible.isEmpty) {
            return Center(
              child: Text(
                l10n.notificationsEmpty,
                style: TextStyle(
                  fontSize: 14,
                  color: AppPalette.of(context).mutedLabel,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _NotificationCard(item: visible[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCompose(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final isWide = MediaQuery.of(context).size.width >= 900;
    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _ComposeSheet(user: user, isDialog: true),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _ComposeSheet(user: user, isDialog: false),
        ),
      );
    }
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});
  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupsAsync = ref.watch(allGroupsProvider);
    final user = ref.watch(currentUserProvider);
    final isOwn = user != null && user.id == item.senderUserId;
    final isAdmin = user?.role == UserRole.admin;
    final canDelete = isOwn || isAdmin;
    final isSystem = item.sender.role == UserRole.system;
    // System notifications get a yellow accent strip + subtle yellow card
    // tint, regardless of accentColor (server blanks it out for SYSTEM anyway).
    final accent = isSystem
        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
        : accentColorOf(item.sender.accentColor, isDark: isDark);
    final cardFill = isSystem
        ? Color.alphaBlend(
            (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                .withOpacity(isDark ? 0.28 : 0.55),
            c.lessonCardFill,
          )
        : c.lessonCardFill;
    final cardBorder = isSystem
        ? (isDark ? const Color(0xFF92400E) : const Color(0xFFFCD34D))
        : c.lessonCardBorder;

    final scopeText = item.scope == NotificationScope.global
        ? l10n.notificationsScopeGlobal
        : _groupNames(groupsAsync.asData?.value, item.targetGroupIds);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (!item.isRead) {
          try {
            await ref
                .read(notificationsProvider.notifier)
                .markRead(item.id);
          } catch (_) {}
        }
      },
      onLongPress: canDelete
          ? () => _showMenu(context, ref, canDelete: canDelete)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: cardFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  // Keep type-based color flair for read items at reduced
                  // opacity; full opacity for unread (dot also disappears).
                  color: accent.withOpacity(item.isRead ? 0.30 : 1.0),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  // 9a: Row with Expanded body and time at far-right edge.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _RoleChip(role: item.sender.role),
                                if (!isSystem) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      item.sender.login,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.lessonCardTitle,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.body,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: item.isRead
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                                color: c.lessonCardTitle,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _MetaChip(
                                  icon: item.scope == NotificationScope.global
                                      ? Icons.public
                                      : Icons.groups,
                                  label: scopeText,
                                ),
                                if (item.linkedDate != null)
                                  _MetaChip(
                                    icon: Icons.event,
                                    label: l10n.notificationsLinkedDate(
                                        _formatDate(l10n, item.linkedDate!)),
                                    highlight: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(l10n, item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: c.lessonCardSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _groupNames(List<NamedRef>? all, List<int> ids) {
    if (all == null || all.isEmpty) return ids.join(', ');
    final byId = {for (final g in all) g.id: g.name};
    final names =
        ids.map((id) => byId[id] ?? id.toString()).toList(growable: false);
    return names.join(' ');
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref,
      {required bool canDelete}) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(l10n.commonDelete,
                    style: const TextStyle(color: Colors.red)),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.commonCancel),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
    if (choice == 'delete') {
      try {
        await ref.read(notificationsProvider.notifier).delete(item.id);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonErrorWith(e.toString()))),
        );
      }
    }
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (bg, fg, label) = switch (role) {
      UserRole.admin => (
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
          l10n.roleChipAdmin,
        ),
      UserRole.teacher => (
          const Color(0xFFDBEAFE),
          const Color(0xFF1E40AF),
          l10n.roleChipTeacher,
        ),
      UserRole.student => (
          const Color(0xFFE5E7EB),
          const Color(0xFF374151),
          l10n.roleChipStudent,
        ),
      UserRole.system => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          l10n.roleChipSystem,
        ),
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkBg = switch (role) {
      UserRole.admin => const Color(0xFF7F1D1D),
      UserRole.teacher => const Color(0xFF1E3A8A),
      UserRole.student => const Color(0xFF374151),
      UserRole.system => const Color(0xFF78350F),
    };
    final darkFg = switch (role) {
      UserRole.admin => const Color(0xFFFECACA),
      UserRole.teacher => const Color(0xFFBFDBFE),
      UserRole.student => const Color(0xFFE5E7EB),
      UserRole.system => const Color(0xFFFDE68A),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? darkBg : bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? darkFg : fg,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    if (highlight) {
      bg = scheme.errorContainer;
      fg = scheme.onErrorContainer;
    } else {
      bg = c.emptySlotFill;
      fg = c.lessonCardSubtitle;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({required this.user, required this.isDialog});
  final AppUser user;
  final bool isDialog;

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  late NotificationScope _scope;
  final Set<int> _selectedGroups = {};
  final TextEditingController _body = TextEditingController();
  final TextEditingController _groupSearch = TextEditingController();
  String _groupFilter = '';
  Timer? _searchDebounce;
  DateTime? _linkedDate;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Teachers can only send to groups; admins default to global.
    _scope = widget.user.role == UserRole.admin
        ? NotificationScope.global
        : NotificationScope.group;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _body.dispose();
    _groupSearch.dispose();
    super.dispose();
  }

  void _onGroupSearchChanged(String raw) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _groupFilter = raw.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupsAsync = ref.watch(allGroupsProvider);
    final isAdmin = widget.user.role == UserRole.admin;
    final isTeacher = widget.user.role == UserRole.teacher;
    final teacherGlobalAllowed = isTeacher && widget.user.canBroadcastGlobally;
    final canSelectGlobal = isAdmin || teacherGlobalAllowed;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        widget.isDialog ? 16 : 8,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.notificationsComposeTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (canSelectGlobal) ...[
            _FieldLabel(l10n.notificationsRecipients),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<NotificationScope>(
                    title: Text(l10n.notificationsGlobal),
                    value: NotificationScope.global,
                    groupValue: _scope,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _scope = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<NotificationScope>(
                    title: Text(l10n.notificationsByGroup),
                    value: NotificationScope.group,
                    groupValue: _scope,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _scope = v!),
                  ),
                ),
              ],
            ),
          ] else ...[
            _FieldLabel(l10n.notificationsRecipients),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l10n.notificationsByGroup,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          if (_scope == NotificationScope.group) ...[
            const SizedBox(height: 8),
            _FieldLabel(l10n.notificationsGroups),
            TextField(
              controller: _groupSearch,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: l10n.notificationsGroupSearch,
                border: const OutlineInputBorder(),
                suffixIcon: _groupFilter.isEmpty && _groupSearch.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: l10n.commonClear,
                        onPressed: _busy
                            ? null
                            : () {
                                _groupSearch.clear();
                                _searchDebounce?.cancel();
                                setState(() => _groupFilter = '');
                              },
                      ),
              ),
              onChanged: _onGroupSearchChanged,
            ),
            const SizedBox(height: 8),
            groupsAsync.when(
              loading: () =>
                  const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (e, _) => Text(
                l10n.notificationsGroupsLoadError,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              data: (groups) {
                final filter = _groupFilter;
                final visible = filter.isEmpty
                    ? groups
                    : groups
                        .where((g) => g.name.toLowerCase().contains(filter))
                        .toList();
                if (visible.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      l10n.commonNothingFound,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in visible)
                      FilterChip(
                        label: Text(g.name),
                        selected: _selectedGroups.contains(g.id),
                        onSelected: _busy
                            ? null
                            : (sel) => setState(() {
                                  if (sel) {
                                    _selectedGroups.add(g.id);
                                  } else {
                                    _selectedGroups.remove(g.id);
                                  }
                                }),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          _FieldLabel(l10n.notificationsMessage),
          TextField(
            controller: _body,
            maxLines: 5,
            maxLength: 2000,
            enabled: !_busy,
            decoration: InputDecoration(
              hintText: l10n.notificationsMessageHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          _FieldLabel(l10n.notificationsLinkDate),
          Row(
            children: [
              if (_linkedDate == null)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text(l10n.notificationsPickDate),
                )
              else
                InputChip(
                  avatar: const Icon(Icons.event, size: 16),
                  label: Text(l10n.notificationsLinkedDate(
                      _formatDate(l10n, _linkedDate!))),
                  onDeleted:
                      _busy ? null : () => setState(() => _linkedDate = null),
                  onPressed: _busy ? null : _pickDate,
                ),
            ],
          ),
          if (_linkedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.notificationsLinkedDateHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _canSubmit() && !_busy ? _submit : null,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(l10n.notificationsSend),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSubmit() {
    if (_body.text.trim().isEmpty) return false;
    if (_scope == NotificationScope.group && _selectedGroups.isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _linkedDate ?? now,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() => _linkedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
          ));
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(notificationsProvider.notifier).send(
            scope: _scope,
            groupIds: _scope == NotificationScope.group
                ? _selectedGroups.toList()
                : const [],
            body: _body.text.trim(),
            linkedDate: _linkedDate,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsSent)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _humanize(l10n, e.toString());
        _busy = false;
      });
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.mutedLabel,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              l10n.notificationsLoadError(message),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(AppLocalizations l10n, DateTime d) =>
    '${d.day} ${_monthGen(l10n, d.month)}';

String _relativeTime(AppLocalizations l10n, DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inSeconds < 60) return l10n.notificationsRelJustNow;
  if (diff.inMinutes < 60) return l10n.notificationsRelMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.notificationsRelHours(diff.inHours);
  if (diff.inDays < 7) return l10n.notificationsRelDays(diff.inDays);
  return '${when.day}.${when.month.toString().padLeft(2, '0')}.${when.year}';
}

String _humanize(AppLocalizations l10n, String raw) {
  var msg = raw.replaceFirst('Exception: ', '').trim();
  if (msg.startsWith('OperationException')) msg = l10n.notificationsServerError;
  if (msg.isEmpty) return l10n.commonError;
  return msg[0].toUpperCase() + msg.substring(1);
}
