
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider_shopper/screens/ChangePasswordScreen.dart';
import 'package:provider_shopper/screens/LoginScreen.dart';
import 'package:provider_shopper/screens/NewsScreen.dart';
import 'package:provider_shopper/screens/NotificationSettingScreen.dart';
import 'package:provider_shopper/screens/ProfileScreen.dart';
import 'package:provider_shopper/screens/RaspisaneScreen.dart';
import 'package:provider_shopper/screens/RegisterScreen.dart';
import 'package:provider_shopper/screens/SettingScreen.dart';



final GlobalKey<NavigatorState> _rootNavigatorKey =
GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
GlobalKey<NavigatorState>(debugLabel: 'shell');

GoRouter router() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => NavigationExample(child: child,),
          routes: [
            GoRoute(
              path: '/raspisanie',
              builder: (context, state) => const RaspisaneScreen(),

            ),
            GoRoute(
              path: '/news',
              builder: (context, state) => const NewsScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingScreen(),
      ),
      GoRoute(
        path: '/settings/changepassword',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
    ],
  );
}


class NavigationExample extends StatelessWidget {
  const NavigationExample({super.key, required this.child});


  final Widget child;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          switch(index){
            case 0:
              GoRouter.of(context).go('/news');
              break;
            case 1:
              GoRouter.of(context).go('/raspisanie');
              break;
            case 2:
              GoRouter.of(context).go('/settings');
              break;
            default:
              GoRouter.of(context).go('/login');
          }
        },
        selectedIndex: 1,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.explore),
            label: 'news',
          ),
          NavigationDestination(
            icon: Icon(Icons.commute),
            label: 'raspisanie',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.bookmark),
            icon: Icon(Icons.bookmark_border),
            label: 'settings',
          ),
        ],
      ),

    );
  }
}
