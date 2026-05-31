import 'dart:async' show StreamSubscription, unawaited;
import 'dart:io' show File, FileSystemException;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/graphql_config.dart';
import '../api/offline_json_cache_store.dart';
import '../api/queries.dart';
import '../api/schedule_cache_store.dart';
import '../common/accent_color.dart';
import '../common/theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_user.dart';
import '../push/push_manager.dart';
import '../state/auth.dart';
import '../state/connectivity.dart';
import '../state/debug_clock.dart';
import '../state/device_prefs.dart';
import '../state/note_queue.dart';
import '../state/schedule_filters.dart';
import '../state/settings.dart';
import '../widgets/honeycomb_color_picker.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

class SettingScreen extends ConsumerWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hideEmpty = ref.watch(hideEmptySlotsProvider).asData?.value ?? false;
    final showLessonProgress =
        ref.watch(showLessonProgressProvider).asData?.value ?? true;
    final viewMode = ref.watch(scheduleViewModeProvider).asData?.value ??
        ScheduleViewMode.grid;
    final themeMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    final locale = ref.watch(localeProvider).asData?.value;
    final dynamicColorEnabled =
        ref.watch(dynamicColorEnabledProvider).asData?.value ?? true;
    final themeSeedHex = ref.watch(themeSeedProvider).asData?.value;
    final dayColoringMode = ref.watch(dayColoringModeProvider).asData?.value ??
        DayColoringMode.auto;
    final pkgInfo = ref.watch(_packageInfoProvider).asData?.value;
    final user = ref.watch(currentUserProvider);
    final isAuthed = user != null;
    final isAdmin = user?.role == UserRole.admin;
    final canPickColor =
        user?.role == UserRole.teacher || user?.role == UserRole.admin;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsAccount,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (!isAuthed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(l10n.settingsNotLoggedIn),
                      subtitle: Text(l10n.settingsLoginToSync),
                      trailing: FilledButton(
                        onPressed: () => context.go('/login'),
                        child: Text(l10n.settingsLogin),
                      ),
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person),
                      title: Text(user.login),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleLabel(l10n, user.role),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: OutlinedButton.icon(
                        onPressed: () => _logout(context, ref),
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(l10n.settingsLogout),
                      ),
                    ),
                  if (isAuthed) ...[
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: Text(l10n.settingsChangePassword),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openChangePassword(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isAuthed) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settingsPushTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    const _NotificationPrefsTiles(),
                  ],
                ),
              ),
            ),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 12),
            const _DebugCard(),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsInterface,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(l10n.settingsHideEmptySlots),
                      ),
                      Switch(
                        value: hideEmpty,
                        onChanged: (v) =>
                            ref.read(hideEmptySlotsProvider.notifier).set(v),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(l10n.settingsShowLessonProgress),
                      ),
                      Switch(
                        value: showLessonProgress,
                        onChanged: (v) => ref
                            .read(showLessonProgressProvider.notifier)
                            .set(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.settingsScheduleView),
                  const SizedBox(height: 6),
                  _EqualSegmented<ScheduleViewMode>(
                    entries: [
                      _SegEntry(
                          ScheduleViewMode.grid, l10n.settingsScheduleViewGrid),
                      _SegEntry(ScheduleViewMode.dayStrip,
                          l10n.settingsScheduleViewDayStrip),
                      _SegEntry(ScheduleViewMode.weekList,
                          l10n.settingsScheduleViewWeekList),
                    ],
                    selected: viewMode,
                    onChanged: (v) =>
                        ref.read(scheduleViewModeProvider.notifier).set(v),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.settingsDayColoring),
                  const SizedBox(height: 6),
                  _EqualSegmented<DayColoringMode>(
                    entries: [
                      _SegEntry(
                          DayColoringMode.auto, l10n.settingsDayColoringAuto),
                      _SegEntry(DayColoringMode.hasLessons,
                          l10n.settingsDayColoringHasLessons),
                      _SegEntry(DayColoringMode.evenOdd,
                          l10n.settingsDayColoringEvenOdd),
                    ],
                    selected: dayColoringMode,
                    onChanged: (v) =>
                        ref.read(dayColoringModeProvider.notifier).set(v),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.settingsTheme),
                  const SizedBox(height: 6),
                  _EqualSegmented<ThemeMode>(
                    entries: [
                      _SegEntry(ThemeMode.system, l10n.settingsThemeSystem),
                      _SegEntry(ThemeMode.light, l10n.settingsThemeLight),
                      _SegEntry(ThemeMode.dark, l10n.settingsThemeDark),
                    ],
                    selected: themeMode,
                    onChanged: (v) =>
                        ref.read(themeModeProvider.notifier).set(v),
                  ),
                  const SizedBox(height: 12),
                  _ThemeSeedPicker(
                    currentHex: themeSeedHex,
                    disabled: !kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.android &&
                        dynamicColorEnabled,
                  ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.settingsDynamicColor),
                              Text(
                                l10n.settingsDynamicColorHint,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: dynamicColorEnabled,
                          onChanged: (v) => ref
                              .read(dynamicColorEnabledProvider.notifier)
                              .set(v),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(l10n.settingsLanguage),
                  const SizedBox(height: 6),
                  _EqualSegmented<String>(
                    entries: [
                      _SegEntry('system', l10n.settingsLanguageSystem),
                      _SegEntry('ru', l10n.settingsLanguageRu),
                      _SegEntry('en', l10n.settingsLanguageEn),
                    ],
                    selected: locale?.languageCode ?? 'system',
                    onChanged: (v) {
                      final next = switch (v) {
                        'ru' => const Locale('ru'),
                        'en' => const Locale('en'),
                        _ => null,
                      };
                      ref.read(localeProvider.notifier).set(next);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (canPickColor && user != null) ...[
            const SizedBox(height: 12),
            _AccentColorCard(current: user.accentColor),
          ],
          const SizedBox(height: 12),
          const _ClearCacheCard(),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                pkgInfo != null
                    ? l10n.settingsVersion(pkgInfo.version, pkgInfo.buildNumber)
                    : l10n.settingsVersionLoading,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context, WidgetRef ref) {
    // State cleared synchronously inside logout(); navigate immediately.
    ref.read(authProvider.notifier).logout();
    context.go('/login');
  }

  Future<void> _openChangePassword(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }
}

class _AccentColorCard extends ConsumerStatefulWidget {
  const _AccentColorCard({required this.current});
  final String? current;

  @override
  ConsumerState<_AccentColorCard> createState() => _AccentColorCardState();
}

class _AccentColorCardState extends ConsumerState<_AccentColorCard> {
  bool _busy = false;

  Future<void> _apply(String? hex) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).setAccentColor(hex);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context).commonErrorWith(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPicker() async {
    final current = parseHexColor(widget.current);
    final picked = await showHoneycombColorPicker(
      context: context,
      current: current,
    );
    if (picked == null || !mounted) return;
    int colorCh(double v) => (v * 255.0).round().clamp(0, 255);
    final r = colorCh(picked.r);
    final g = colorCh(picked.g);
    final b = colorCh(picked.b);
    final hex =
        '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
    await _apply(hex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final currentColor = parseHexColor(widget.current);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsAccentTitle,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              l10n.settingsAccentHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: currentColor ?? Colors.red.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _openPicker,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.settingsAccentPick),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed:
                  (_busy || widget.current == null) ? null : () => _apply(null),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.settingsAccentDefault),
            ),
          ],
        ),
      ),
    );
  }
}

/// Device-local theme seed picker — the "Цвет темы" control. Same visual
/// layout as [_AccentColorCard] so the two pickers are immediately
/// recognisable as the same kind of control, but writes to the local
/// `themeSeedProvider` (no server mutation) and is disabled when Material
/// You is on since MY takes over the seed either way.
class _ThemeSeedPicker extends ConsumerStatefulWidget {
  const _ThemeSeedPicker({required this.currentHex, required this.disabled});
  final String? currentHex;
  final bool disabled;

  @override
  ConsumerState<_ThemeSeedPicker> createState() => _ThemeSeedPickerState();
}

class _ThemeSeedPickerState extends ConsumerState<_ThemeSeedPicker> {
  bool _busy = false;

  Future<void> _apply(String? hex) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(themeSeedProvider.notifier).set(hex);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPicker() async {
    // Seed only contributes its HUE through `DynamicSchemeVariant.tonalSpot`;
    // saturation/lightness are ignored. Restrict the control to hue and emit
    // a fully-saturated, fully-bright seed so Material has a vivid source to
    // derive tones from.
    final existing = parseHexColor(widget.currentHex);
    final startHue = existing != null ? HSVColor.fromColor(existing).hue : 0.0;
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _HuePickerDialog(initialHue: startHue),
    );
    if (picked == null || !mounted) return;
    int colorCh(double v) => (v * 255.0).round().clamp(0, 255);
    final r = colorCh(picked.r);
    final g = colorCh(picked.g);
    final b = colorCh(picked.b);
    final hex =
        '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
    await _apply(hex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final currentColor = parseHexColor(widget.currentHex);
    return Opacity(
      opacity: widget.disabled ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: widget.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsThemeSeedTitle),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: currentColor ?? scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: (_busy || widget.disabled) ? null : _openPicker,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.settingsAccentPick),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: (_busy || widget.disabled || widget.currentHex == null)
                  ? null
                  : () => _apply(null),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.settingsAccentDefault),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();
  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final cur = _current.text;
    final nxt = _next.text;
    final cfm = _confirm.text;
    if (cur.isEmpty || nxt.length < 6 || nxt != cfm) {
      setState(() => _error = l10n.settingsChangePasswordHint);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(changePasswordMutation),
      variables: {'currentPassword': cur, 'newPassword': nxt},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (r.hasException) {
      setState(() {
        _busy = false;
        _error = r.exception!.graphqlErrors.isNotEmpty
            ? r.exception!.graphqlErrors.first.message
            : l10n.commonError;
      });
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsChangePasswordDone)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsChangePasswordTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _current,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.settingsChangePasswordCurrent,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon:
                      Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _next,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.settingsChangePasswordNew,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.settingsChangePasswordRepeat,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.settingsChangePasswordSubmit),
        ),
      ],
    );
  }
}

enum _NotifCategory { news, announcements, scheduleChanges }

class _NotificationPrefsTiles extends ConsumerStatefulWidget {
  const _NotificationPrefsTiles();
  @override
  ConsumerState<_NotificationPrefsTiles> createState() =>
      _NotificationPrefsTilesState();
}

class _NotificationPrefsTilesState
    extends ConsumerState<_NotificationPrefsTiles> with WidgetsBindingObserver {
  _NotifCategory? _busy;
  // Seed from the in-process cache so the first frame already reflects the
  // real permission. Without this, toggles backed by the cached server pref
  // would flash ON for a tick before the async probe resolved to
  // notDetermined and the effective-state mask turned them off.
  PushPermission _perm = cachedPushPermission;
  StreamSubscription<PushPermission>? _permSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permSub = pushPermissionStream.listen((p) {
      if (!mounted) return;
      setState(() => _perm = p);
    });
    unawaited(_refreshPermission());
    // Reconcile prefs on mount: the current-device row may have been created
    // server-side (all-on) after a token rotation since the last session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(devicePrefsProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    _permSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may flip browser/OS notification permission outside the app;
    // re-read whenever we regain focus so the UI reflects reality.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermission());
    }
  }

  Future<void> _refreshPermission() async {
    final p = await readPushPermission();
    if (!mounted) return;
    setState(() => _perm = p);
  }

  Future<void> _toggle(_NotifCategory cat, bool v) async {
    // notDetermined + user flips ON → trigger the interactive permission
    // flow first. On success, continue with the pref write; otherwise flip
    // the switch back and surface a SnackBar.
    if (v && _perm == PushPermission.notDetermined) {
      final granted =
          await requestPermissionInteractively(context, ref.container);
      if (!mounted) return;
      await _refreshPermission();
      if (!mounted) return;
      if (!granted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pushPermissionDeniedSnack)),
        );
        return;
      }
    }

    setState(() => _busy = cat);
    try {
      await ref.read(devicePrefsProvider.notifier).applyPatch(
            news: cat == _NotifCategory.news ? v : null,
            announcements: cat == _NotifCategory.announcements ? v : null,
            scheduleChanges: cat == _NotifCategory.scheduleChanges ? v : null,
          );
      if (cat == _NotifCategory.scheduleChanges) {
        await syncScheduleChangeTopic(ref.container);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _showBlockedHelp() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pushPermissionBlockedHelpTitle),
        content: Text(kIsWeb
            ? l10n.pushPermissionBlockedHelpBodyWeb
            : l10n.pushPermissionBlockedHelpBodyMobile),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.pushPermissionBlockedHelpOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocked = _perm == PushPermission.denied;
    final pending = _perm == PushPermission.notDetermined;
    final token = ref.watch(currentFcmTokenProvider);
    final prefs = ref.watch(devicePrefsProvider).asData?.value;
    // No token yet (permission not granted, or FCM hasn't issued one yet) →
    // the toggles have nothing to write to. Show them OFF + disabled with a
    // subtitle. The 1.0.27 permission effective-state mask still applies on
    // top of that.
    final tokenUnknown = token == null || token.isEmpty;
    final wantsNews = (!blocked && prefs != null) ? prefs.news : false;
    final wantsAnn = (!blocked && prefs != null) ? prefs.announcements : false;
    final wantsSc = (!blocked && prefs != null) ? prefs.scheduleChanges : false;
    // When permission hasn't been granted yet, visually show toggles as OFF:
    // pushes won't arrive until permission is granted regardless of server
    // pref, so OFF is the honest state.
    final showOnNews = _perm == PushPermission.granted && wantsNews;
    final showOnAnn = _perm == PushPermission.granted && wantsAnn;
    final showOnSc = _perm == PushPermission.granted && wantsSc;
    // Pending (permission prompt not yet answered) takes visual precedence
    // over tokenUnknown — the next tap will open the prompt.
    final tileDisabled = blocked;
    final subtitleKind = blocked
        ? _PrefSubtitleKind.none
        : pending
            ? _PrefSubtitleKind.pending
            : tokenUnknown
                ? _PrefSubtitleKind.tokenUnknown
                : _PrefSubtitleKind.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blocked)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kIsWeb
                        ? l10n.pushPermissionBlocked
                        : l10n.pushPermissionBlockedMobile,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.pushPermissionBlockedHelpTitle,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: _showBlockedHelp,
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
          ),
        _PrefTile(
          icon: Icons.newspaper,
          title: l10n.settingsPrefNews,
          value: showOnNews,
          busy: _busy == _NotifCategory.news,
          disabled: tileDisabled,
          subtitleKind: subtitleKind,
          onChanged: (v) => _toggle(_NotifCategory.news, v),
        ),
        _PrefTile(
          icon: Icons.campaign_outlined,
          title: l10n.settingsPrefAnnouncements,
          value: showOnAnn,
          busy: _busy == _NotifCategory.announcements,
          disabled: tileDisabled,
          subtitleKind: subtitleKind,
          onChanged: (v) => _toggle(_NotifCategory.announcements, v),
        ),
        _PrefTile(
          icon: Icons.event_repeat,
          title: l10n.settingsPrefScheduleChanges,
          value: showOnSc,
          busy: _busy == _NotifCategory.scheduleChanges,
          disabled: tileDisabled,
          subtitleKind: subtitleKind,
          onChanged: (v) => _toggle(_NotifCategory.scheduleChanges, v),
        ),
      ],
    );
  }
}

enum _PrefSubtitleKind { none, pending, tokenUnknown }

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final bool busy;
  final bool disabled;
  final _PrefSubtitleKind subtitleKind;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.busy,
    required this.onChanged,
    this.disabled = false,
    this.subtitleKind = _PrefSubtitleKind.none,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    String? subtitleText;
    switch (subtitleKind) {
      case _PrefSubtitleKind.pending:
        // Compact hint when the toggle will trigger the permission prompt on
        // the next tap (notDetermined state).
        subtitleText = l10n.pushRationaleBodyWeb.split('\n').first;
        break;
      case _PrefSubtitleKind.tokenUnknown:
        subtitleText = l10n.settingsPrefTokenPending;
        break;
      case _PrefSubtitleKind.none:
        subtitleText = null;
        break;
    }
    final tapDisabled =
        disabled || subtitleKind == _PrefSubtitleKind.tokenUnknown;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitleText == null
            ? null
            : Text(
                subtitleText,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: value,
                onChanged: tapDisabled ? null : onChanged,
              ),
      ),
    );
  }
}

class _DebugCard extends ConsumerWidget {
  const _DebugCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final override = ref.watch(debugClockProvider).asData?.value;
    final online = ref.watch(isOnlineProvider).asData?.value ?? true;
    final queue = ref.watch(noteQueueProvider).asData?.value ?? const [];
    final lastFlush = ref.watch(noteQueueTelemetryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsDebugTitle,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(l10n.settingsDebugTestTime)),
                Switch(
                  value: override != null,
                  onChanged: (on) async {
                    if (!on) {
                      await ref.read(debugClockProvider.notifier).clear();
                    } else {
                      final picked = await _pickDateTime(context, override);
                      if (picked != null) {
                        await ref.read(debugClockProvider.notifier).set(picked);
                      }
                    }
                  },
                ),
              ],
            ),
            if (override != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDateTime(context, override),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await _pickDateTime(context, override);
                      if (picked != null) {
                        await ref.read(debugClockProvider.notifier).set(picked);
                      }
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(l10n.commonEdit),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            _DebugRow(
              label: l10n.settingsDebugConnState,
              value:
                  online ? l10n.settingsDebugOnline : l10n.settingsDebugOffline,
              valueColor: online ? Colors.green : Colors.red,
            ),
            _DebugRow(
              label: l10n.settingsDebugNoteQueue,
              value: queue.isEmpty
                  ? l10n.settingsDebugQueueEmpty
                  : l10n.settingsDebugQueueOps(queue.length),
            ),
            _DebugRow(
              label: l10n.settingsDebugLastSync,
              value:
                  lastFlush == null ? '—' : _formatDateTime(context, lastFlush),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const _FcmTokenButton(),
                OutlinedButton.icon(
                  onPressed: () => _forceFlush(context, ref),
                  icon: const Icon(Icons.sync, size: 16),
                  label: Text(l10n.settingsDebugForceSync),
                ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  OutlinedButton.icon(
                    onPressed: () => _showWidgetLog(context),
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: Text(l10n.settingsDebugWidgetLog),
                  ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/settings/palette-debug'),
                  icon: const Icon(Icons.palette_outlined, size: 16),
                  label: Text(l10n.settingsDebugPalette),
                ),
                OutlinedButton.icon(
                  onPressed: () => _clearLocalStorage(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(l10n.settingsDebugClearStorage),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FcmTokenButton extends StatefulWidget {
  const _FcmTokenButton();

  @override
  State<_FcmTokenButton> createState() => _FcmTokenButtonState();
}

class _FcmTokenButtonState extends State<_FcmTokenButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                await _showFcmToken(context);
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.key, size: 16),
      label: Text(l10n.settingsDebugShowFcm),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime? current) async {
  final l10n = AppLocalizations.of(context);
  final seed = current ?? DateTime.now();
  final d = await showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: DateTime(seed.year - 5),
    lastDate: DateTime(seed.year + 5),
    helpText: l10n.settingsDebugDatePickHelp,
    cancelText: l10n.commonCancel,
    confirmText: l10n.commonNext,
  );
  if (d == null) return null;
  if (!context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(seed),
    helpText: l10n.settingsDebugTimePickHelp,
    cancelText: l10n.commonCancel,
    confirmText: l10n.commonOk,
  );
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

String _monthShort(AppLocalizations l10n, int month) {
  return switch (month) {
    1 => l10n.monthShortJan,
    2 => l10n.monthShortFeb,
    3 => l10n.monthShortMar,
    4 => l10n.monthShortApr,
    5 => l10n.monthShortMay,
    6 => l10n.monthShortJun,
    7 => l10n.monthShortJul,
    8 => l10n.monthShortAug,
    9 => l10n.monthShortSep,
    10 => l10n.monthShortOct,
    11 => l10n.monthShortNov,
    _ => l10n.monthShortDec,
  };
}

String _formatDateTime(BuildContext context, DateTime d) {
  final l10n = AppLocalizations.of(context);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_monthShort(l10n, d.month)} ${d.year}, $hh:$mm';
}

Future<void> _showFcmToken(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  String token;
  try {
    token = (await FirebaseMessaging.instance.getToken()) ??
        l10n.settingsDebugFcmUnavailable;
  } catch (e) {
    token = l10n.settingsDebugFcmError(e.toString());
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.settingsDebugFcmTitle),
      content: SizedBox(
        width: 400,
        child: SelectableText(
          token,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: token));
            if (!ctx.mounted) return;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(l10n.commonCopied)),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: Text(l10n.commonCopy),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    ),
  );
}

Future<void> _forceFlush(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  try {
    await ref.read(noteQueueProvider.notifier).flush();
    if (!context.mounted) return;
    final remaining = ref.read(noteQueueProvider).asData?.value.length ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(remaining == 0
            ? l10n.settingsDebugQueueEmptyMsg
            : l10n.settingsDebugQueueNotSent(remaining)),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.commonErrorWith(e.toString()))),
    );
  }
}

/// 1.3.2: subtle "Очистить кеш" card surfaced for ALL users (not just admin),
/// distinct from the debug "Очистить локальное хранилище" tile inside
/// [_DebugCard]. Wipes the bounded schedule cache plus the saved filter;
/// preserves auth so the user keeps their session.
class _ClearCacheCard extends ConsumerWidget {
  const _ClearCacheCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsClearCache,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsClearCacheHint,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _clearScheduleCache(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(l10n.settingsClearCache),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wipes the schedule cache + saved filter.
/// - ScheduleCacheStore.clear() → persisted schedule rows gone.
/// - OfflineJsonCacheStore.clear() → notes/notifications snapshots gone.
/// - GraphQL in-memory store reset → current-session normalized cache gone.
/// - scheduleFiltersProvider.notifier.clear() → saved filter prefs cleared.
/// Auth is NOT touched — the user keeps their token and cached identity.
Future<void> _clearScheduleCache(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.settingsClearCacheConfirmTitle),
      content: Text(l10n.settingsClearCacheConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.commonClear),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(scheduleCacheStoreProvider).clear();
    await ref.read(offlineJsonCacheStoreProvider).clear();
    ref.read(graphqlClientProvider).cache.store.reset();
    ref.read(scheduleFiltersProvider.notifier).clear();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.commonErrorWith(e.toString()))),
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.settingsClearCacheDone),
    ),
  );
}

Future<void> _clearLocalStorage(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.settingsDebugClearConfirmTitle),
      content: Text(l10n.settingsDebugClearConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.commonClear),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    // Preserve the auth token on web (where it's stored in SharedPreferences
    // rather than secure storage).
    final preservedAuth = kIsWeb ? prefs.getString('auth_token_v1') : null;
    await prefs.clear();
    if (preservedAuth != null) {
      await prefs.setString('auth_token_v1', preservedAuth);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.commonErrorWith(e.toString()))),
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.settingsDebugClearDone),
    ),
  );
}

Future<void> _showWidgetLog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final dir = await getExternalStorageDirectory();
  if (!context.mounted) return;
  if (dir == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsDebugWidgetLogUnavailable)),
    );
    return;
  }
  final file = File('${dir.path}/widget-errors.log');
  String contents;
  try {
    contents = await file.readAsString();
  } on FileSystemException {
    contents = '';
  }
  if (!context.mounted) return;
  final isEmpty = contents.isEmpty;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('widget-errors.log'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: SingleChildScrollView(
          child: SelectableText(
            isEmpty ? l10n.settingsDebugWidgetLogEmpty : contents,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: contents));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.colorPickerCopied)),
                  );
                },
          child: Text(l10n.commonCopy),
        ),
        TextButton(
          onPressed: isEmpty
              ? null
              : () async {
                  try {
                    await file.writeAsString('');
                  } catch (_) {}
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
          child: Text(l10n.commonClear),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    ),
  );
}

class _SegEntry<T> {
  const _SegEntry(this.value, this.label);
  final T value;
  final String label;
}

/// Segmented control that renders consistently across form factors:
/// full-width on mobile (<600dp) with segments distributed equally, capped
/// at 380dp and left-aligned on wider layouts. Segments always reserve at
/// least the widest label's *bold-weight* intrinsic width so flipping
/// selection never changes widths (the "dance"), and ellipsis is allowed
/// only as a last-ditch overflow guard on abnormally narrow containers.
class _EqualSegmented<T> extends StatelessWidget {
  const _EqualSegmented({
    required this.entries,
    required this.selected,
    required this.onChanged,
  });
  final List<_SegEntry<T>> entries;
  final T selected;
  final ValueChanged<T> onChanged;

  // Material 3 ButtonSegment: 12px horizontal padding on each side +
  // 1px divider between segments. Budget the overhead per segment so
  // label widths sum back to the container width.
  static const _perSegmentOverhead = 26.0;
  static const _wideCap = 380.0;
  static const _wideBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final baseStyle =
        Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final measureStyle = baseStyle.copyWith(fontWeight: FontWeight.w600);
    double maxLabelWidth = 0;
    for (final e in entries) {
      final tp = TextPainter(
        text: TextSpan(text: e.label, style: measureStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (tp.width > maxLabelWidth) maxLabelWidth = tp.width;
    }
    final minLabelWidth = maxLabelWidth.ceilToDouble() + 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final groupWidth = isWide ? _wideCap : constraints.maxWidth;
        final computed = (groupWidth - _perSegmentOverhead * entries.length) /
            entries.length;
        final labelWidth = computed < minLabelWidth ? minLabelWidth : computed;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: groupWidth,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final e in entries)
                  ButtonSegment<T>(
                    value: e.value,
                    label: SizedBox(
                      width: labelWidth,
                      child: Text(
                        e.label,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
              ],
              selected: {selected},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        );
      },
    );
  }
}

/// Hue-only theme-seed picker. Exposes a 0–360° slider on a rainbow track;
/// the returned color is always `HSV(hue, 1, 1)` so `tonalSpot` receives a
/// vivid seed to derive its tones from.
class _HuePickerDialog extends StatefulWidget {
  const _HuePickerDialog({required this.initialHue});
  final double initialHue;

  @override
  State<_HuePickerDialog> createState() => _HuePickerDialogState();
}

class _HuePickerDialogState extends State<_HuePickerDialog> {
  late double _hue = widget.initialHue.clamp(0.0, 360.0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final previewColor = HSVColor.fromAHSV(1, _hue, 1, 1).toColor();
    return AlertDialog(
      title: Text(l10n.settingsThemeSeedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: previewColor,
              borderRadius: BorderRadius.circular(kButtonRadius),
              border: Border.all(color: scheme.outlineVariant, width: 1),
            ),
          ),
          const SizedBox(height: 16),
          _HueSlider(
            hue: _hue,
            onChanged: (v) => setState(() => _hue = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(previewColor),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

/// 0–360° hue slider painted as a rainbow gradient. Thumb is a circular
/// swatch showing the current hue, outlined with the active color scheme.
class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});
  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 10,
        trackShape: const _RainbowTrackShape(),
        thumbShape: _HueThumbShape(outline: scheme.outline),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTrackColor: Colors.transparent,
        inactiveTrackColor: Colors.transparent,
      ),
      child: Slider(
        min: 0,
        max: 360,
        value: hue.clamp(0.0, 360.0),
        onChanged: onChanged,
      ),
    );
  }
}

class _RainbowTrackShape extends SliderTrackShape {
  const _RainbowTrackShape();

  static const List<Color> _stops = [
    Color(0xFFFF0000), // 0° red
    Color(0xFFFFFF00), // 60° yellow
    Color(0xFF00FF00), // 120° green
    Color(0xFF00FFFF), // 180° cyan
    Color(0xFF0000FF), // 240° blue
    Color(0xFFFF00FF), // 300° magenta
    Color(0xFFFF0000), // 360° back to red
  ];

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 10.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      trackLeft,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final radius = Radius.circular(rect.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final paint = Paint()
      ..shader = const LinearGradient(colors: _stops).createShader(rect);
    context.canvas.drawRRect(rrect, paint);
  }
}

class _HueThumbShape extends SliderComponentShape {
  const _HueThumbShape({required this.outline});
  final Color outline;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(11);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final hue = (value * 360).clamp(0.0, 360.0);
    final fill = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawCircle(center, 11, Paint()..color = fill);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline,
    );
  }
}
