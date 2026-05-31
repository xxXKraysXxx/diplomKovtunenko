import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/app_user.dart';
import '../screens/AdminScreen.dart';
import '../screens/ChangePasswordScreen.dart';
import '../screens/EmbedScheduleScreen.dart';
import '../screens/LoginScreen.dart';
import '../screens/NewsScreen.dart';
import '../screens/NotificationSettingScreen.dart';
import '../screens/NotificationsScreen.dart';
import '../screens/PaletteDebugScreen.dart';
import '../screens/RegisterScreen.dart';
import '../screens/ScheduleScreen.dart';
import '../screens/SettingScreen.dart';
import '../state/auth.dart';
import '../state/gate.dart';
import '../state/notifications.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Plumbs auth state into a [Listenable] so GoRouter re-evaluates
/// its redirect whenever auth flips.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authProvider, (_, __) => notifyListeners());
    _ref.listen<AsyncValue<bool>>(gateSeenProvider, (_, __) => notifyListeners());
    _ref.listen<AsyncValue<bool>>(guestModeChosenProvider, (_, __) => notifyListeners());
  }
  // ignore: unused_field
  final Ref _ref;
}

bool _isDesktopOrWeb() {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

Page<dynamic> _buildPage({
  required Widget child,
  required GoRouterState state,
}) {
  final key = state.pageKey;
  final name = state.name;
  if (_isDesktopOrWeb()) {
    return CustomTransitionPage<void>(
      key: key,
      name: name,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (ctx, anim, _, c) =>
          FadeTransition(opacity: anim, child: c),
    );
  }
  return CustomTransitionPage<void>(
    key: key,
    name: name,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (ctx, anim, secondary, c) {
      final inTween = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOut));
      final outTween = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(1, 0),
      ).chain(CurveTween(curve: Curves.easeIn));
      return SlideTransition(
        position: anim.drive(inTween),
        child: SlideTransition(
          position: secondary.drive(outTween),
          child: c,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/schedule',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;
      final isAuthed = auth.asData?.value.isAuthenticated ?? false;
      final guestChosen = ref.read(guestModeChosenProvider).asData?.value ?? false;
      final loc = state.uri.toString();
      final isEmbed = loc.startsWith('/embed');
      if (loc == '/gate') {
        return '/login';
      }
      final isPublic =
          loc == '/login' || loc == '/register' || isEmbed;

      // Only allow unauthenticated users past the guard if they explicitly
      // chose guest mode. gate_seen alone is not sufficient.
      if (!isAuthed && !isPublic && !guestChosen) {
        return '/login';
      }
      // Deliberately: the embed route keeps rendering for authed users too
      // (iframe host stays on /embed after the in-dialog login).
      if (isAuthed && (loc == '/login' || loc == '/register')) {
        return '/schedule';
      }
      if (loc.startsWith('/admin')) {
        final user = auth.asData?.value.user;
        if (user == null || user.role != UserRole.admin) {
          return '/schedule';
        }
      }
      if (loc.startsWith('/notifications') && !isAuthed) {
        return '/schedule';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) =>
            _buildPage(child: const LoginScreen(), state: s),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (c, s) =>
            _buildPage(child: const RegisterScreen(), state: s),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (c, s) =>
            _buildPage(child: const AdminScreen(), state: s),
      ),
      GoRoute(
        path: '/embed',
        pageBuilder: (c, s) =>
            _buildPage(child: const EmbedScheduleScreen(), state: s),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        pageBuilder: (c, s, child) => _buildPage(
          child: _ShellScaffold(child: child),
          state: s,
        ),
        routes: [
          GoRoute(
            path: '/schedule',
            pageBuilder: (c, s) =>
                _buildPage(child: const ScheduleScreen(), state: s),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (c, s) =>
                _buildPage(child: const NotificationsScreen(), state: s),
          ),
          GoRoute(
            path: '/news',
            pageBuilder: (c, s) =>
                _buildPage(child: const NewsScreen(), state: s),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (c, s) =>
                _buildPage(child: const SettingScreen(), state: s),
          ),
        ],
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (c, s) =>
            _buildPage(child: const NotificationSettingScreen(), state: s),
      ),
      GoRoute(
        path: '/settings/changepassword',
        pageBuilder: (c, s) =>
            _buildPage(child: const ChangePasswordScreen(), state: s),
      ),
      GoRoute(
        path: '/settings/palette-debug',
        pageBuilder: (c, s) =>
            _buildPage(child: const PaletteDebugScreen(), state: s),
      ),
    ],
  );
});

class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.child});
  final Widget child;

  // Order: News | Notifications | Schedule | Settings | Admin
  static List<_NavItem> _itemsFor(AppLocalizations l10n) => [
        _NavItem(
          label: l10n.navNews,
          icon: Icons.newspaper,
          route: '/news',
        ),
        _NavItem(
          label: l10n.navNotifications,
          icon: Icons.notifications_outlined,
          route: '/notifications',
          authOnly: true,
          showBadge: true,
        ),
        _NavItem(
          label: l10n.navSchedule,
          icon: Icons.calendar_month,
          route: '/schedule',
        ),
        _NavItem(
          label: l10n.navSettings,
          icon: Icons.settings,
          route: '/settings',
        ),
        _NavItem(
          label: l10n.navAdmin,
          icon: Icons.admin_panel_settings,
          route: '/admin',
          adminOnly: true,
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loc = GoRouterState.of(context).uri.toString();
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.role == UserRole.admin;
    final isAuthed = user != null;
    final items = [
      for (final i in _itemsFor(l10n))
        if ((!i.adminOnly || isAdmin) && (!i.authOnly || isAuthed)) i,
    ];
    final selectedIndex = () {
      for (var i = 0; i < items.length; i++) {
        if (loc.startsWith(items[i].route)) return i;
      }
      return 0;
    }();
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;

    final isWide = MediaQuery.of(context).size.width >= 900;

    Widget iconFor(_NavItem i) {
      final icon = Icon(i.icon);
      if (i.showBadge && unread > 0) {
        return Badge.count(count: unread, child: icon);
      }
      return icon;
    }

    // Android system back: hook the Router's BackButtonDispatcher directly.
    // PopScope was getting swallowed by go_router's own shell PopScope
    // (`canPop: match.matches.length == 1` in builder.dart line 300), which
    // let the root navigator pop the ShellRoute page and exit the app.
    // BackButtonListener fires *before* popRoute() reaches the router, so
    // we can force tab redirection without fighting the delegate.
    final onSchedule = loc.startsWith('/schedule');
    Widget wrapBack(Widget w) => BackButtonListener(
          onBackButtonPressed: () async {
            if (onSchedule) return false; // let system handle (exits app)
            ref.read(routerProvider).go('/schedule');
            return true;
          },
          child: w,
        );

    void onSelect(int i) {
      final route = items[i].route;
      GoRouter.of(context).go(route);
      // Auto-mark notifications as read whenever the user taps the
      // notifications destination — covers both fresh mounts and the case
      // where the page state survives between visits (e.g. tab re-activation
      // on desktop/web). Keeps mobile and PC behaviour symmetric.
      if (route == '/notifications') {
        Future.microtask(() {
          unawaited(ref.read(notificationsProvider.notifier).autoMarkAllRead());
        });
      }
    }

    if (isWide) {
      return wrapBack(Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: onSelect,
              destinations: [
                for (final i in items)
                  NavigationRailDestination(
                    icon: iconFor(i),
                    label: Text(
                      i.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      ));
    }

    return wrapBack(Scaffold(
      body: child,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              overflow: TextOverflow.ellipsis,
              fontSize: 11,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final i in items)
              NavigationDestination(
                icon: iconFor(i),
                label: i.label,
                tooltip: i.label,
              ),
          ],
        ),
      ),
    ));
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.adminOnly = false,
    this.authOnly = false,
    this.showBadge = false,
  });
  final String label;
  final IconData icon;
  final String route;
  final bool adminOnly;
  final bool authOnly;
  final bool showBadge;
}

// Retained for compatibility with any old imports.
GoRouter router() {
  if (kDebugMode) {
    debugPrint('router() factory is deprecated; use routerProvider.');
  }
  throw UnimplementedError('Use routerProvider instead of router().');
}
