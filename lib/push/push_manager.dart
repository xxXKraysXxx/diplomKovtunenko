import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/graphql_config.dart';
import '../api/queries.dart';
import '../common/cold_launch_timing.dart';
import '../firebase_options.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show scaffoldMessengerKey;
import '../route/go_router_provider.dart';
import '../state/device_prefs.dart';
import '../state/notifications.dart';
import 'schedule_change_refresh.dart';

// Public VAPID key for web push — safe to commit (client-only material).
// Override at build time with --dart-define=WEB_VAPID_KEY=<new key>.
const _webVapidKey = String.fromEnvironment(
  'WEB_VAPID_KEY',
  defaultValue:
      'BMKqCrxt-N1wLcno0gSSeJnxZffigjySWRSYZn5x_x77GKPNc6ER95bVe3yk-IJmZNaaRfuA-RNkvXOb750gvk8',
);

/// Background message handler. Must be a top-level function with
/// `@pragma('vm:entry-point')` so Flutter's AOT build includes it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final scheduleChange = parseScheduleChangePayload(message.data);
  if (scheduleChange != null) {
    await recordPendingScheduleChangePayload(scheduleChange);
  }
  // OS renders notification payloads automatically; data-only schedule
  // refreshes are consumed from SharedPreferences when the UI resumes.
}

String _platformName() {
  if (kIsWeb) return 'web';
  try {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
  } catch (_) {}
  return 'unknown';
}

bool _platformSupportsFcm() => _platformName() != 'unknown';

bool _platformSupportsTopics() {
  final p = _platformName();
  return p == 'android' || p == 'ios';
}

StreamSubscription<String>? _tokenRefreshSub;
StreamSubscription<RemoteMessage>? _foregroundSub;
StreamSubscription<RemoteMessage>? _openedSub;
bool _bootstrapped = false;
const _scheduleTopicGroupPrefKey = 'schedule_change_topic_group_id_v1';
const _scheduleDesiredGroupPrefKey = 'schedule_change_desired_group_id_v1';

/// Called once at app start. Wires global listeners and — if the user is
/// already authed — registers the current FCM token.
Future<void> pushBootstrap(ProviderContainer container) async {
  logTiming('push.bootstrap.entry');
  if (_bootstrapped) return;
  if (!_platformSupportsFcm()) return;
  _bootstrapped = true;

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  logTiming('push.bootstrap.after_bg_handler');

  // Prime the cached push-permission value so the Settings screen can render
  // the correct effective toggle state on its first frame, without a flash of
  // server-pref-driven values while the async probe resolves.
  unawaited(readPushPermission());

  _foregroundSub?.cancel();
  _foregroundSub = FirebaseMessaging.onMessage.listen((msg) {
    _handleForeground(container, msg);
  });

  _openedSub?.cancel();
  _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    _handleOpenedFromTap(container, msg);
  });

  _tokenRefreshSub?.cancel();
  _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
    _registerAndSyncTopics(container, t);
  });

  // If a tap on a push launched the app cold, FCM stores it in
  // getInitialMessage.
  try {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleOpenedFromTap(container, initial);
  } catch (_) {}
  logTiming('push.bootstrap.exit');

  // Token registration on cold-start used to be driven by a synchronous
  // `authProvider.read()` here. That read raced `Auth.build()` — at boot time
  // the AsyncNotifier is still loading, so `asData` was usually null and the
  // branch silently no-op'd. Result: "Ждём регистрации устройства…" stuck in
  // Settings until the user manually flipped a toggle. The auth-listener in
  // `MyApp.build` is now the single source of truth for guest→authed
  // transitions (cold-start verification AND interactive login both flip the
  // state through that listener), so registration always lands.
}

const _rationaleShownPrefKey = 'notifications_rationale_shown_v1';
// Flips to true only once the native OS permission prompt has actually been
// invoked and resolved (regardless of granted/denied outcome). Needed because
// on Android 13+ FCM's `getNotificationSettings` reports `denied` pre-prompt,
// so "real denial" can't be distinguished from "never asked" without this
// separate flag. Must NOT be piggy-backed on `_rationaleShownPrefKey` — the
// rationale-shown pref also flips when the user taps "Later", which should
// leave us in notDetermined (no OS prompt fired).
const _osPromptAskedPrefKey = 'notifications_os_prompt_asked_v1';

/// Reads the current OS-level notification permission as a simple enum.
/// Wraps [FirebaseMessaging.getNotificationSettings] so UI code can switch on
/// it without pulling in the Firebase types.
enum PushPermission { granted, denied, notDetermined, unsupported }

// Cached last-known permission so the first frame of the Settings screen can
// render the correct effective state synchronously, without a one-frame flash
// of stale (server-pref-driven) values while the async probe resolves.
PushPermission _cachedPushPermission = PushPermission.notDetermined;
PushPermission get cachedPushPermission => _cachedPushPermission;

// Broadcast-stream of permission transitions so UI listeners can react
// without polling (e.g. the Settings toggles updating after a resume).
final _pushPermissionController = StreamController<PushPermission>.broadcast();
Stream<PushPermission> get pushPermissionStream =>
    _pushPermissionController.stream;

Future<PushPermission> readPushPermission() async {
  final result = await _probePushPermission();
  if (result != _cachedPushPermission) {
    _cachedPushPermission = result;
    _pushPermissionController.add(result);
  }
  return result;
}

Future<PushPermission> _probePushPermission() async {
  if (!_platformSupportsFcm()) return PushPermission.unsupported;
  try {
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    switch (s.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PushPermission.granted;
      case AuthorizationStatus.denied:
        // Android 13+ reports `denied` before the user has ever been asked, so
        // a fresh install would incorrectly render as "blocked". Treat denied
        // as notDetermined on Android until the OS prompt has actually fired
        // and resolved. We gate on `_osPromptAsked` — NOT the rationale-shown
        // pref — because rationale-shown also flips when the user taps
        // "Later", which must leave us in notDetermined (no system prompt
        // was invoked).
        if (_platformName() == 'android' && !await _osPromptAsked()) {
          return PushPermission.notDetermined;
        }
        return PushPermission.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermission.notDetermined;
    }
  } catch (_) {
    return PushPermission.unsupported;
  }
}

Future<bool> _osPromptAsked() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_osPromptAskedPrefKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> _markOsPromptAsked() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_osPromptAskedPrefKey, true);
  } catch (_) {}
}

/// Called after a successful login / register.
///
/// - granted → fetch current FCM token and register it silently.
/// - denied → do nothing (user unblocks in browser/OS settings).
/// - notDetermined, rationale never shown → show the first-ever rationale
///   exactly once; on Allow fire requestPermission + register and default all
///   three category prefs ON; on dismiss leave prefs alone and mark the
///   rationale as seen so it never auto-shows again.
/// - notDetermined, rationale already seen → do nothing automatically. The
///   user opts in later by flipping a Settings toggle (which calls
///   [requestPermissionInteractively]).
///
/// Critically, requestPermission() is NEVER called without an explicit user
/// gesture (rationale "Allow" or Settings toggle). Some browsers' gestureless
/// permission policy silently rejects such calls and puts permission into a
/// terminal "denied" state — the rework avoids that trap.
Future<void> onAuthenticated(
  ProviderContainer container, {
  int? scheduleGroupId,
}) async {
  if (!_platformSupportsFcm()) return;
  await _setDesiredScheduleGroup(scheduleGroupId);

  try {
    final perm = await readPushPermission();
    if (perm == PushPermission.granted) {
      // Already authorized — just refresh/register the token.
      await _fetchAndRegister(container);
      return;
    }
    if (perm == PushPermission.denied) return;
    // notDetermined from here on.
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_rationaleShownPrefKey) ?? false;
    if (seen) return; // User already decided; do not nag.

    // Post-login navigation is still settling; give the root navigator a
    // frame so the rationale dialog latches onto the new overlay.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final requestFuture = await _showRationale(context);
    // Mark seen regardless — user has now been asked once on this device.
    // Fire-and-forget so no microtask sits between the Allow tap and the
    // permission request that it kicked off.
    unawaited(prefs.setBool(_rationaleShownPrefKey, true));
    if (requestFuture == null) return;

    // The device prefs row is created all-on by the backend on first write,
    // so no explicit default-on call is needed after the permission grant —
    // _fetchAndRegister inside _finalizePermissionRequest will register the
    // token and the next devicePushPrefs read will reflect the server row.
    await _finalizePermissionRequest(container, requestFuture);
  } catch (_) {
    // Swallow — push is best-effort; never block auth flows.
  }
}

/// Explicit user-gesture path from the Settings toggle. Shows the rationale,
/// fires [FirebaseMessaging.requestPermission] (the native prompt), and
/// registers the token on success. Returns true if permission is granted
/// after the flow.
Future<bool> requestPermissionInteractively(
  BuildContext context,
  ProviderContainer container,
) async {
  if (!_platformSupportsFcm()) return false;
  try {
    final current = await readPushPermission();
    if (current == PushPermission.granted) {
      await _fetchAndRegister(container);
      return true;
    }
    if (current == PushPermission.denied) return false;
    if (!context.mounted) return false;
    final requestFuture = await _showRationale(context);
    // Fire-and-forget so no await sits between the Allow tap and the
    // permission request fired inside it (browsers invalidate gesture
    // tracking after an intervening microtask).
    unawaited(_markRationaleSeen());
    if (requestFuture == null) return false;
    return _finalizePermissionRequest(container, requestFuture);
  } catch (_) {
    return false;
  }
}

Future<void> _markRationaleSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rationaleShownPrefKey, true);
  } catch (_) {}
}

Future<bool> _finalizePermissionRequest(
  ProviderContainer container,
  Future<NotificationSettings> pending,
) async {
  NotificationSettings settings;
  try {
    settings = await pending;
  } catch (_) {
    return false;
  }
  // The OS prompt has now fired and resolved — regardless of granted/denied,
  // future `denied` reads can be trusted as real user denial rather than the
  // Android 13+ pre-prompt default.
  unawaited(_markOsPromptAsked());
  final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
  // Re-read so the cached/broadcast state reflects the browser's new value.
  await readPushPermission();
  if (!ok) return false;
  await _fetchAndRegister(container);
  return true;
}

Future<void> _fetchAndRegister(ProviderContainer container) async {
  logTiming('push.fetch_token.start');
  final token = kIsWeb
      ? await FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey)
      : await FirebaseMessaging.instance.getToken();
  logTiming('push.fetch_token.end');
  if (token == null || token.isEmpty) return;
  await _registerAndSyncTopics(container, token);
  logTiming('push.register.end');
}

// Returns the Future<NotificationSettings> that was kicked off *synchronously*
// with the user's "Allow" tap, or null if the user dismissed ("Later"/"Not
// now"). Critical for web: FirebaseMessaging.requestPermission() must be
// called from inside the gesture-originating callback — an intervening await
// invalidates the browser's user-activation stamp and the permission prompt
// is silently rejected.
Future<Future<NotificationSettings>?> _showRationale(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  if (kIsWeb) {
    return showDialog<Future<NotificationSettings>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.notifications_active,
            color: Theme.of(ctx).colorScheme.primary),
        title: Text(l10n.pushRationaleTitle),
        content: Text(
          l10n.pushRationaleBodyWeb,
          style: const TextStyle(fontSize: 14, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.pushRationaleLater),
          ),
          FilledButton(
            onPressed: () {
              // Fire requestPermission() synchronously within the tap handler
              // so the browser counts it against the current user gesture.
              final pending = FirebaseMessaging.instance.requestPermission();
              Navigator.of(ctx).pop(pending);
            },
            child: Text(l10n.pushRationaleAllow),
          ),
        ],
      ),
    );
  }
  return showModalBottomSheet<Future<NotificationSettings>?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active,
                      color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    l10n.pushRationaleTitle,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pushRationaleBodyMobile,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: Text(l10n.pushRationaleNotNow),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final pending =
                          FirebaseMessaging.instance.requestPermission();
                      Navigator.of(ctx).pop(pending);
                    },
                    child: Text(l10n.pushRationaleAllow),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Called from Auth.logout(). Best-effort: we tell the backend to drop the
/// token, then delete it locally so the next login flow gets a fresh one.
Future<void> onLogout(ProviderContainer container) async {
  if (!_platformSupportsFcm()) return;
  await _setDesiredScheduleGroup(null);
  await syncScheduleChangeTopic(container);
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      final client = container.read(graphqlClientProvider);
      await client.mutate(MutationOptions(
        document: gql(unregisterDeviceTokenMutation),
        variables: {'token': token},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
    }
  } catch (_) {}
  try {
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {}
  try {
    container.read(currentFcmTokenProvider.notifier).set(null);
    container.invalidate(devicePrefsProvider);
  } catch (_) {}
}

Future<void> _registerAndSyncTopics(
  ProviderContainer container,
  String token,
) async {
  await _register(container, token);
  await syncScheduleChangeTopic(container);
}

Future<void> _register(ProviderContainer container, String token) async {
  // Publish the token to the local provider FIRST, before any network round-
  // trip. Settings UI gates the "Ждём регистрации устройства…" subtitle on
  // this provider — making it depend on a backend ack would leave the toggles
  // pinned to "pending" any time the network was slow or the server stalled.
  // The provider write is purely local (synchronous Riverpod state set), so
  // it can never throw on the unauth path; it's only wrapped in try/catch
  // because Riverpod lookups during shutdown can race a disposed container.
  bool tokenChanged = true;
  try {
    final prev = container.read(currentFcmTokenProvider);
    tokenChanged = prev != token;
    container.read(currentFcmTokenProvider.notifier).set(token);
    if (tokenChanged) {
      // Token rotation invalidates the per-token cached prefs row.
      container.invalidate(devicePrefsProvider);
    }
  } catch (_) {}
  // Now tell the backend. Failure here is non-fatal — the local provider
  // already advertised the token to the UI, and the next token-refresh tick
  // (or auth-listener fire) retries the mutation.
  try {
    final client = container.read(graphqlClientProvider);
    await client.mutate(MutationOptions(
      document: gql(registerDeviceTokenMutation),
      variables: {'token': token, 'platform': _platformName()},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
  } catch (_) {}
}

Future<void> _setDesiredScheduleGroup(int? groupId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (groupId == null) {
      await prefs.remove(_scheduleDesiredGroupPrefKey);
    } else {
      await prefs.setInt(_scheduleDesiredGroupPrefKey, groupId);
    }
  } catch (_) {}
}

Future<int?> _readIntPref(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  } catch (_) {
    return null;
  }
}

Future<void> _writeSubscribedScheduleGroup(int? groupId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (groupId == null) {
      await prefs.remove(_scheduleTopicGroupPrefKey);
    } else {
      await prefs.setInt(_scheduleTopicGroupPrefKey, groupId);
    }
  } catch (_) {}
}

String _scheduleTopicForGroup(int groupId) => 'group-$groupId';

Future<void> syncScheduleChangeTopic(ProviderContainer container) async {
  if (!_platformSupportsTopics()) return;
  final desiredGroup = await _readIntPref(_scheduleDesiredGroupPrefKey);
  final prefs = container.read(devicePrefsProvider).asData?.value;
  final wantsScheduleChanges = prefs?.scheduleChanges ?? true;
  final targetGroup = wantsScheduleChanges ? desiredGroup : null;
  final currentGroup = await _readIntPref(_scheduleTopicGroupPrefKey);
  if (currentGroup == targetGroup) return;

  try {
    if (currentGroup != null) {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic(_scheduleTopicForGroup(currentGroup));
    }
    if (targetGroup != null) {
      await FirebaseMessaging.instance
          .subscribeToTopic(_scheduleTopicForGroup(targetGroup));
    }
    await _writeSubscribedScheduleGroup(targetGroup);
  } catch (_) {}
}

void _handleForeground(ProviderContainer container, RemoteMessage msg) {
  final scheduleChange = parseScheduleChangePayload(msg.data);
  if (scheduleChange != null) {
    refreshScheduleForChange(container, scheduleChange);
    return;
  }

  try {
    container.invalidate(notificationsProvider);
  } catch (_) {}
  // Bump the unread badge counter on every incoming foreground push.
  // We don't gate on `data.kind` — the FCM payload alternates between
  // notification-shape (OS-rendered) and data-shape, and the server
  // doesn't currently mark the difference reliably enough to filter.
  // Increment-on-any keeps the badge responsive; the resume safety-net
  // and any explicit markAllRead/delete paths reconcile to the server's
  // authoritative count if drift ever shows up.
  try {
    container.read(unreadCountProvider.notifier).incrementForPush();
  } catch (_) {}

  final n = msg.notification;
  final body = (n?.body?.trim().isNotEmpty ?? false)
      ? n!.body!
      : (msg.data['body']?.toString() ?? '');
  if (body.isEmpty) return;

  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final l10n = AppLocalizations.of(messenger.context);
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
      action: SnackBarAction(
        label: l10n.pushSnackbarOpen,
        onPressed: () {
          try {
            container.read(routerProvider).go('/notifications');
          } catch (_) {}
        },
      ),
    ),
  );
}

void _handleOpenedFromTap(ProviderContainer container, RemoteMessage msg) {
  final scheduleChange = parseScheduleChangePayload(msg.data);
  if (scheduleChange != null) {
    refreshScheduleForChange(container, scheduleChange);
    try {
      container.read(routerProvider).go('/schedule');
    } catch (_) {}
    return;
  }

  final linked = msg.data['linked_date']?.toString();
  try {
    final router = container.read(routerProvider);
    if (linked != null && linked.isNotEmpty) {
      router.go('/schedule?date=$linked');
    } else {
      router.go('/notifications');
    }
  } catch (_) {}
}
