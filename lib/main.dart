import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ncti_schedule_client/common/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'api/graphql_config.dart';
import 'api/raspisanie_repository.dart';
import 'common/accent_color.dart';
import 'common/cold_launch_timing.dart';
import 'common/embed_bridge.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'push/push_manager.dart' as push;
import 'push/schedule_change_refresh.dart' as schedule_push;
import 'route/go_router_provider.dart';
import 'state/auth.dart';
import 'state/debug_clock.dart';
import 'state/gate.dart';
import 'state/guest_note_migration.dart';
import 'state/lifecycle.dart';
import 'state/note_queue.dart';
import 'state/notifications.dart'
    show notificationsProvider, unreadCountProvider;
import 'state/palette_overrides.dart';
import 'state/schedule_filters.dart';
import 'state/settings.dart'
    show
        dynamicColorEnabledProvider,
        themeModeProvider,
        themeSeedProvider,
        localeProvider;
import 'theme/app_palette.dart' show PaletteTokens;
import 'widgets_home/widget_deep_link.dart' as widgets_home_links;
import 'widgets_home/widget_updater.dart' as widgets_home;

/// Global messenger key so providers can surface snackbars without
/// holding a widget BuildContext.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  logTiming('main.start');
  WidgetsFlutterBinding.ensureInitialized();
  logTiming('main.after_binding');
  // Prime SharedPreferences before any provider touches it. This avoids the
  // web-plugin-not-ready race that surfaced as "MissingPluginException:
  // No implementation found for method getAll" during second login attempts.
  // Also stash the resolved instance so the schedule-filter notifier (1.3.2)
  // can sync-seed itself from disk on first read.
  try {
    final prefs = await SharedPreferences.getInstance();
    scheduleFilterPrimedPrefs = prefs;
  } catch (_) {}
  logTiming('main.after_shared_prefs');
  // GraphQL cache is intentionally memory-only. Persistent schedule rows are
  // handled by a small bounded cache outside graphql_flutter, so cold start no
  // longer opens the old eager HiveStore.
  logTiming('main.after_graphql_cache_skip');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase not configured for this platform (Windows/Linux) — skip.
  }
  logTiming('main.after_firebase');
  await _maybeMarkGateSeenForEmbed();
  await _setupDesktopWindow();
  logTiming('main.runapp');
  runApp(const ProviderScope(child: MyApp()));
}

/// Embed route must bypass the /gate redirect so the iframe loads the
/// schedule immediately. Flip the persisted flag on startup if the initial
/// URL points at the embed surface.
Future<void> _maybeMarkGateSeenForEmbed() async {
  if (!kIsWeb) return;
  try {
    final url = Uri.base.toString();
    if (url.contains('/embed')) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(gateSeenPrefKey) ?? false)) {
        await prefs.setBool(gateSeenPrefKey, true);
      }
    }
  } catch (_) {}
}

Future<void> _setupDesktopWindow() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

  // Set before MaterialApp mounts, so we can't reach AppLocalizations yet.
  // The window title gets overridden per-frame via MaterialApp.onGenerateTitle
  // once the widget tree is up.
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(480, 640),
    center: true,
    title: 'KTI Schedule',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setResizable(true);
    await windowManager.show();
    await windowManager.focus();
  });
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

/// TTL gates for the resume auto-refresh. Picked tight enough that a user
/// returning after a normal break (lunch, lecture switch) still sees fresh
/// data, loose enough that a quick app-switcher swap is a no-op. Together
/// with Riverpod's keepAlive caching, this prevents the "loads a lot of
/// stuff" jank a user reported on background→foreground transitions: the
/// raspisanie + notifications providers are NOT touched on every resume,
/// only when their last fetch is genuinely stale.
const _kResumeNotificationsTtl = Duration(minutes: 2);
const _kResumeRaspisanieTtl = Duration(minutes: 5);

/// Delay before auto-retrying the auth verify after a resume from a
/// "backend unreachable" state. Short enough to feel automatic, long enough
/// for Android's connectivity stack to finish its post-wake DNS dance —
/// without this guard, the immediate retry usually loses the same race that
/// produced the original "Failed host lookup".
const _kResumeAutoRetryDelay = Duration(milliseconds: 800);

/// Window after launch during which the lifecycle observer ignores the
/// `inactive→resumed` transition that Android emits as part of the cold
/// start itself. Without this, the observer fires its smart-resume
/// invalidations on top of the already-running cold-fetch path,
/// double-loading the very providers we're trying to make snappier.
/// Genuine post-launch backgroundings happen well after 3 seconds.
const _kPostLaunchResumeSuppressionWindow = Duration(seconds: 3);

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  // Stamps used by the smart-resume gate. Initialized to "now" at startup
  // so the very first foreground tick after launch doesn't immediately
  // invalidate everything (the cold-start path already fetched fresh).
  DateTime _lastNotificationsRefreshAt = DateTime.now();
  DateTime _lastRaspisanieRefreshAt = DateTime.now();
  // Stamped once in initState so the early post-launch resume cascade can
  // be suppressed. Final to make the intent — "moment the app object was
  // created" — explicit; reassignment would defeat the suppression.
  late final DateTime _launchedAt;

  @override
  void initState() {
    super.initState();
    _launchedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget: registers FCM listeners and — if already authed —
    // sends the current device token to the backend.
    final container = ProviderScope.containerOf(context, listen: false);
    unawaited(push.pushBootstrap(container));
    unawaited(schedule_push.consumePendingScheduleChange(container));
    widgets_home.startWidgetUpdateLoop(container);
    widgets_home_links.installWidgetDeepLinkHandler(container);
    // Kick the note queue off the cold-start path so any pending offline
    // writes start flushing without waiting for the schedule screen.
    container.read(noteQueueProvider);
    // Warm the debug-clock pref so schedule UI paths see the override on
    // first frame instead of a brief wall-clock flicker.
    container.read(debugClockProvider);
    if (kIsWeb) {
      listenEmbedTheme((theme) {
        final mode = switch (theme.toLowerCase()) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        };
        container.read(themeModeProvider.notifier).set(mode);
      });
      listenEmbedLocale((code) {
        final locale = switch (code.toLowerCase()) {
          'ru' => const Locale('ru'),
          'en' => const Locale('en'),
          _ => null,
        };
        container.read(localeProvider.notifier).set(locale);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    logTiming('lifecycle.resumed');
    // Suppress the cold-launch `inactive→resumed` tick. Android emits this
    // as part of the launch sequence itself; treating it as a real resume
    // re-invalidates raspisanie + notifications on top of the already-running
    // cold-fetch path. The other resume-side effects (resumedAt stamp, note
    // queue flush, backend-unreachable retry) are also redundant here —
    // they only matter for genuine background→foreground transitions.
    if (DateTime.now().difference(_launchedAt) <
        _kPostLaunchResumeSuppressionWindow) {
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    // Stamp the resume instant FIRST so handlers reading the provider
    // (the auth-failure overlay gate) see a fresh value before any
    // resume-driven refetch can fail and route through it.
    container.read(resumedAtProvider.notifier).mark(DateTime.now());
    // Always: retry pending offline note writes. Cheap no-op when the queue
    // is empty.
    container.read(noteQueueProvider.notifier).flush();
    unawaited(schedule_push.consumePendingScheduleChange(container));

    // Issue 3: if we resumed onto the "backend unreachable" overlay, retry
    // the auth verify after a brief delay. The most common cause of that
    // overlay on resume is the post-wake DNS race (Android tears down the
    // socket layer while backgrounded; the first request after resume
    // fails with "Failed host lookup" before the resolver is back up).
    final hadError = container.read(backendUnreachableProvider) != null;
    if (hadError) {
      Future.delayed(_kResumeAutoRetryDelay, () {
        if (!mounted) return;
        if (container.read(backendUnreachableProvider) == null) return;
        container.read(backendUnreachableProvider.notifier).clear();
        container.invalidate(authProvider);
      });
    }

    // Issue 5: smart resume — gate every refetch behind a TTL so quick
    // app-switches don't trigger work. The GraphQL client, Hive cache,
    // theme pipeline, and FCM token registration are intentionally NOT
    // re-initialized on resume; only data that the user perceives as
    // potentially stale (notifications + the displayed month's schedule)
    // gets refreshed, and only past the TTL boundary.
    final authed =
        container.read(authProvider).asData?.value.isAuthenticated ?? false;
    if (!authed) return;
    final now = DateTime.now();
    if (now.difference(_lastNotificationsRefreshAt) >
        _kResumeNotificationsTtl) {
      _lastNotificationsRefreshAt = now;
      container.invalidate(notificationsProvider);
      // Resume safety-net for the unread badge: a push that lands while
      // the app is backgrounded does not fire the foreground onMessage
      // hook, so the in-memory counter would drift. Re-pull the
      // authoritative count from the server. Fire-and-forget — this is
      // a foreground call site so transport failures legitimately route
      // through the auth handler (now lifecycle-gated by part 1).
      // ignore: discarded_futures
      container.read(unreadCountProvider.notifier).refreshForeground();
    }
    if (now.difference(_lastRaspisanieRefreshAt) > _kResumeRaspisanieTtl) {
      _lastRaspisanieRefreshAt = now;
      try {
        final filters = container.read(scheduleFiltersProvider);
        final month = container.read(displayedMonthProvider);
        container.invalidate(monthRaspisanieByMonthProvider(
            monthFilterParamsFor(month, filters)));
      } catch (_) {
        // Filters/displayedMonth providers might not be initialized on a
        // very early resume — silently skip; they'll fetch on first watch
        // anyway.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    final locale = ref.watch(localeProvider).asData?.value;
    final routerCfg = ref.watch(routerProvider);

    ref.listen<int>(sessionExpiredProvider, (prev, next) {
      if (prev == null || next == prev) return;
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      final l10n = AppLocalizations.of(messenger.context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(l10n.sessionExpired),
          action: SnackBarAction(
            label: l10n.sessionExpiredLogin,
            onPressed: () {
              scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
              routerCfg.go('/login');
            },
          ),
        ),
      );
    });

    ref.listen<AsyncValue<AuthState>>(authProvider, (prev, next) {
      final wasAuthed = prev?.asData?.value.isAuthenticated ?? false;
      final isAuthed = next.asData?.value.isAuthenticated ?? false;
      if (!wasAuthed && isAuthed) {
        scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
        // Drain any notes the user created as a guest into their account.
        Future(() async {
          try {
            await migrateGuestNotesToServer(ref.read(graphqlClientProvider));
          } catch (_) {}
        });
        // Single source of truth for push registration. Fires for cold-start
        // (AsyncLoading→AsyncData(authed) on stored-token verify) AND for
        // interactive login (AsyncData(guest)→AsyncData(authed)). Bootstrap
        // used to do this via a sync `authProvider.read()` that raced
        // `Auth.build()`, leaving Settings stuck on "Ждём регистрации
        // устройства…" until the user manually flipped a toggle.
        final container = ProviderScope.containerOf(context, listen: false);
        Future(() async {
          try {
            await push.onAuthenticated(
              container,
              scheduleGroupId: next.asData?.value.user?.groupId,
            );
          } catch (_) {}
        });
      }
    });

    final useDynamic =
        ref.watch(dynamicColorEnabledProvider).asData?.value ?? true;
    final themeSeedHex = ref.watch(themeSeedProvider).asData?.value;
    final themeSeed = parseHexColor(themeSeedHex);
    final overrides =
        ref.watch(paletteOverridesProvider).asData?.value ?? const {};
    final seedOverride = overrides[PaletteTokens.seed];

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;
        // Debug seed override bypasses both Material You and the accent path:
        // the whole scheme gets re-derived from the picked colour so that
        // primary, surfaces and container tones all shift together.
        if (seedOverride != null) {
          lightScheme = buildBrandedScheme(
            seed: seedOverride,
            brightness: Brightness.light,
          );
          darkScheme = buildBrandedScheme(
            seed: seedOverride,
            brightness: Brightness.dark,
          );
        } else if (useDynamic && lightDynamic != null && darkDynamic != null) {
          // Material You: defer entirely to the system seed — including
          // surfaces — per explicit product decision.
          lightScheme = lightDynamic;
          darkScheme = darkDynamic;
        } else {
          // Seed source when Material You is off: the device-local
          // `themeSeed` if set, otherwise shipped defaults.
          final seedLight = themeSeed ?? appDefaultSeedLight;
          final seedDark = themeSeed ?? appDefaultSeedDark;
          lightScheme = buildBrandedScheme(
            seed: seedLight,
            brightness: Brightness.light,
          );
          darkScheme = buildBrandedScheme(
            seed: seedDark,
            brightness: Brightness.dark,
          );
        }
        final effectiveLight =
            buildAppTheme(scheme: lightScheme, paletteOverrides: overrides);
        final effectiveDark =
            buildAppTheme(scheme: darkScheme, paletteOverrides: overrides);
        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
          theme: effectiveLight,
          darkTheme: effectiveDark,
          themeMode: mode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: routerCfg,
          scaffoldMessengerKey: scaffoldMessengerKey,
          builder: (ctx, child) {
            logTiming('material_app.builder.entry');
            final auth = ref.watch(authProvider);
            final backendError = ref.watch(backendUnreachableProvider);
            if (auth.isLoading) {
              // Cold start with NO cached identity — there's nothing to
              // render yet. With cached identity, build() resolves
              // synchronously to authenticated and we skip the splash.
              return const _AuthLoadingSplash();
            }
            final body = child ?? const SizedBox.shrink();
            if (backendError == null) return body;
            // Non-blocking banner. The full UI tree (with whatever cached
            // data it has) renders underneath; the banner overlays the
            // top with a Retry/Dismiss action so the user can still
            // navigate, read notes, see schedule, etc. Replaces the
            // 1.2.10 full-screen blocker which kicked flight-mode users
            // out of the app entirely.
            return Stack(
              children: [
                Positioned.fill(child: body),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: _OfflineBanner(
                      message: backendError,
                      onRetry: () {
                        ref.read(backendUnreachableProvider.notifier).clear();
                        ref.invalidate(authProvider);
                      },
                      onDismiss: () =>
                          ref.read(backendUnreachableProvider.notifier).clear(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AuthLoadingSplash extends StatelessWidget {
  const _AuthLoadingSplash();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// Slim non-blocking banner shown at the top of the app when the backend is
/// unreachable. Replaces the 1.2.10 full-screen blocker — flight-mode users
/// can still read their cached schedule, notifications, and notes; the banner
/// gives them a Retry button without trapping them out of the UI. Dismissible
/// and auto-cleared by any subsequent successful network call.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.offlineBannerMessage,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.offlineBannerRetry),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: scheme.onErrorContainer),
              tooltip: l10n.offlineBannerDismiss,
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
