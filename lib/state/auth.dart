import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/cached_identity_store.dart';
import '../api/graphql_config.dart';
import '../api/queries.dart';
import '../api/token_store.dart';
import '../common/cold_launch_timing.dart';
import '../models/app_user.dart';
import '../push/push_manager.dart' as push;
import 'gate.dart';
import 'lifecycle.dart';
import 'schedule_filters.dart';

/// Bumps each time an authed session silently expires
/// (token rejected by server). The shell listens and shows a snackbar.
class SessionExpiryPulse extends Notifier<int> {
  @override
  int build() => 0;
  void signal() => state = state + 1;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiryPulse, int>(SessionExpiryPulse.new);

/// Holds a human-readable reason when the client can't reach the backend at
/// all (TCP refused, DNS fail, TLS fail, timeout, 5xx). `null` means "no
/// connectivity problem"; any non-null value triggers the full-screen
/// "Что-то пошло не так" overlay in [MyApp.build].
class BackendUnreachable extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? message) => state = message;
  void clear() => state = null;
}

final backendUnreachableProvider =
    NotifierProvider<BackendUnreachable, String?>(BackendUnreachable.new);

/// Thrown from [Auth.build] when verification can't tell the network apart
/// from "invalid token" because the request never reached the server. Caught
/// upstream so we don't silently drop to guest state — the UI shell shows
/// the connection-problem overlay instead.
class BackendUnreachableException implements Exception {
  BackendUnreachableException(this.message);
  final String message;
  @override
  String toString() => message;
}

bool looksUnauthorized(OperationException e) {
  for (final g in e.graphqlErrors) {
    final code =
        (g.extensions?['code'] ?? '').toString().toUpperCase();
    if (code == 'UNAUTHENTICATED' ||
        code == 'UNAUTHORIZED' ||
        code == 'FORBIDDEN' ||
        code == 'INVALID_TOKEN') {
      return true;
    }
    final m = g.message.toLowerCase();
    if (m.contains('unauthorized') ||
        m.contains('unauthenticated') ||
        m.contains('invalid token') ||
        m.contains('token') && m.contains('expired') ||
        m.contains('войдите') ||
        m.contains('авториз')) {
      return true;
    }
  }
  return false;
}

/// Transport-level failure — request never landed at GraphQL (socket
/// refused, TLS fail, DNS fail, timeout, 502/503 gateway). Distinct from a
/// server-side auth error, which arrives as a structured `graphqlErrors`
/// entry with `linkException == null`.
bool looksLikeBackendUnreachable(OperationException e) {
  if (e.linkException != null) return true;
  if (e.graphqlErrors.isEmpty) return true;
  return false;
}

String _networkErrorMessage(OperationException e) {
  final le = e.linkException;
  if (le != null) return le.toString();
  return 'Connection failed';
}

/// Coarse classification of a backend-unreachable failure for the UI shell.
/// Each value maps 1:1 to a localized message in [AppLocalizations]; the raw
/// exception string is stored separately and surfaced in a collapsible
/// "Подробнее" toggle on the error screen so the friendly copy stays clean.
enum BackendErrorKind { offline, server, timeout, unknown }

/// Pattern-matches the raw exception text against the failure modes the user
/// can act on. Cheap heuristic, intentionally permissive: any string that
/// looks like a DNS/socket error becomes [BackendErrorKind.offline]; anything
/// with an explicit 5xx status code becomes [BackendErrorKind.server]; any
/// timeout becomes [BackendErrorKind.timeout]; otherwise [unknown].
BackendErrorKind classifyBackendError(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('timeoutexception') || s.contains('timed out')) {
    return BackendErrorKind.timeout;
  }
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('handshakeexception') ||
      s.contains('no address associated') ||
      s.contains('connection refused') ||
      s.contains('connection closed') ||
      s.contains('network is unreachable') ||
      s.contains('clientexception') ||
      s.contains('xmlhttprequest error')) {
    return BackendErrorKind.offline;
  }
  // 502/503/504 from the reverse proxy or backend itself. Match both
  // "statusCode: 503" formatting and the bare "503 " prefix some link
  // implementations surface.
  final fivexx = RegExp(r'\b5\d\d\b');
  if (fivexx.hasMatch(s)) return BackendErrorKind.server;
  return BackendErrorKind.unknown;
}

sealed class AuthState {
  const AuthState();
  const factory AuthState.guest() = _Guest;
  const factory AuthState.authenticated(
    AppUser user,
    String token,
    ScheduleDefaultFilter defaultFilter,
  ) = _Authenticated;

  bool get isAuthenticated => this is _Authenticated;
  AppUser? get user => switch (this) {
        _Authenticated(:final user) => user,
        _ => null,
      };
  String? get token => switch (this) {
        _Authenticated(:final token) => token,
        _ => null,
      };
  ScheduleDefaultFilter? get defaultFilter => switch (this) {
        _Authenticated(:final defaultFilter) => defaultFilter,
        _ => null,
      };
}

class _Guest extends AuthState {
  const _Guest();
}

class _Authenticated extends AuthState {
  @override
  final AppUser user;
  @override
  final String token;
  @override
  final ScheduleDefaultFilter defaultFilter;
  const _Authenticated(this.user, this.token, this.defaultFilter);
}

class Auth extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    logTiming('auth.build.entry');
    final store = ref.read(tokenStoreProvider);
    final token = await store.load();
    if (token == null || token.isEmpty) {
      // Successful verification clears any leftover "backend unreachable"
      // banner from a previous failed attempt.
      ref.read(backendUnreachableProvider.notifier).clear();
      logTiming('auth.build.exit_guest');
      return const AuthState.guest();
    }
    // Cache-first path: a previously-verified `me` payload lets us seed the
    // UI immediately without waiting on the network. Flight-mode users see
    // their last-seen data; meQuery runs in the background and only mutates
    // auth state on a confirmed 401 (real expiry) or success (refresh).
    final identityStore = ref.read(cachedIdentityStoreProvider);
    final cachedRaw = await identityStore.load();
    if (cachedRaw != null) {
      try {
        final user = AppUser.fromJson(cachedRaw);
        logTiming('auth.build.cached_hit');
        unawaited(_backgroundRefreshMe(token));
        // 1.3.2 Item 2a: belt-and-suspenders for students who somehow lack a
        // saved filter (fresh install, cache wipe, prefs cleared). The saved
        // filter from disk has already loaded into the notifier on its first
        // read; this only fires when that read came up empty.
        _applyStudentGroupAutoDefault(user);
        return AuthState.authenticated(
          user,
          token,
          const ScheduleDefaultFilter(),
        );
      } catch (_) {
        // Stale cached identity shape (e.g. backend renamed a field after a
        // server upgrade). Drop it and fall through to the live verify.
        await identityStore.clear();
      }
    }
    // No cached identity (first launch after install / cleared cache) —
    // we have no choice but to gate the UI on the network. Same path as
    // pre-1.2.11 behavior.
    logTiming('auth.build.cached_miss');
    return _verifyTokenLive(token);
  }

  /// Live token verify. Runs only on first launch (no cached identity) — the
  /// hot path on cold start is the cached-identity branch in [build].
  Future<AuthState> _verifyTokenLive(String token) async {
    final store = ref.read(tokenStoreProvider);
    final identityStore = ref.read(cachedIdentityStoreProvider);
    try {
      logTiming('auth.build.before_me_query');
      final client = ref.read(graphqlClientProvider);
      final r = await client
          .query(QueryOptions(
            document: gql(meQuery),
            fetchPolicy: FetchPolicy.networkOnly,
          ))
          .timeout(const Duration(seconds: 10));
      logTiming('auth.build.me_returned');
      if (r.hasException) {
        final ex = r.exception!;
        if (looksUnauthorized(ex)) {
          // Real session expiry — token was rejected by the server.
          await store.clear();
          await identityStore.clear();
          ref.read(authEpochProvider.notifier).bump();
          ref.read(sessionExpiredProvider.notifier).signal();
          ref.read(backendUnreachableProvider.notifier).clear();
          return const AuthState.guest();
        }
        // Anything else (linkException, transport-level, 5xx) is treated
        // as a backend-unreachable problem — keep the token so a retry
        // can succeed without forcing the user to re-login.
        ref
            .read(backendUnreachableProvider.notifier)
            .set(_networkErrorMessage(ex));
        throw BackendUnreachableException(_networkErrorMessage(ex));
      }
      final raw = r.data?['me'];
      if (raw == null) {
        // `me` returning null without an auth error shouldn't happen;
        // treat it like a session expiry to be safe.
        await store.clear();
        await identityStore.clear();
        ref.read(authEpochProvider.notifier).bump();
        ref.read(sessionExpiredProvider.notifier).signal();
        ref.read(backendUnreachableProvider.notifier).clear();
        return const AuthState.guest();
      }
      final meMap = raw as Map<String, dynamic>;
      final user = AppUser.fromJson(meMap);
      // Persist for next cold start so we can skip the live verify.
      unawaited(identityStore.save(meMap));
      // Successful verification — blow away any pending connection overlay.
      ref.read(backendUnreachableProvider.notifier).clear();
      _applyStudentGroupAutoDefault(user);
      return AuthState.authenticated(
        user,
        token,
        const ScheduleDefaultFilter(),
      );
    } on BackendUnreachableException {
      rethrow;
    } catch (e) {
      // TimeoutException / SocketException / TLS — no structured exception
      // available. Keep the token; surface as connection problem.
      ref.read(backendUnreachableProvider.notifier).set(e.toString());
      throw BackendUnreachableException(e.toString());
    }
  }

  /// Background-refresh of the `me` payload after the cached-identity path
  /// seeded the UI. Outcomes:
  /// - 401 / unauthorized → real session expiry, log the user out.
  /// - Network/timeout failure → keep the user authenticated; the
  ///   non-blocking offline banner surfaces from
  ///   [handleAuthOpFailure] so they know they're on stale data.
  /// - Success → update auth state with fresh user + persist new identity.
  Future<void> _backgroundRefreshMe(String token) async {
    try {
      final client = ref.read(graphqlClientProvider);
      final r = await client.query(QueryOptions(
        document: gql(meQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (r.hasException) {
        final ex = r.exception!;
        if (looksUnauthorized(ex)) {
          // Real expiry — invalidate session.
          await handleSessionExpired();
          return;
        }
        // Surfaces the offline banner (now non-blocking) without touching
        // auth state; user keeps seeing cached data.
        await handleAuthOpFailure(ex);
        return;
      }
      final raw = r.data?['me'];
      if (raw == null) return;
      final meMap = raw as Map<String, dynamic>;
      final user = AppUser.fromJson(meMap);
      await ref.read(cachedIdentityStoreProvider).save(meMap);
      // Successful refresh — clear any banner from a prior failure.
      ref.read(backendUnreachableProvider.notifier).clear();
      final current = state.asData?.value;
      // Preserve the existing default filter (we don't request it on me).
      state = AsyncValue.data(AuthState.authenticated(
        user,
        token,
        current?.defaultFilter ?? const ScheduleDefaultFilter(),
      ));
    } catch (_) {
      // Raw TimeoutException / SocketException — keep authenticated.
    }
  }

  Future<void> login(String login, String password) async {
    final store = ref.read(tokenStoreProvider);
    final client = ref.read(graphqlClientProvider);
    final r = await client
        .mutate(MutationOptions(
          document: gql(loginMutation),
          variables: {'login': login, 'password': password},
          fetchPolicy: FetchPolicy.networkOnly,
        ))
        .timeout(const Duration(seconds: 10));
    if (r.hasException) {
      throw r.exception!;
    }
    final loginRaw = r.data!['login'] as Map<String, dynamic>;
    final payload = LoginPayload.fromJson(loginRaw);
    await store.save(payload.token);
    final userRaw = loginRaw['user'];
    if (userRaw is Map<String, dynamic>) {
      unawaited(ref.read(cachedIdentityStoreProvider).save(userRaw));
    }
    ref.read(authEpochProvider.notifier).bump();
    _applyDefaultFilter(payload.defaultFilter);
    _applyStudentGroupAutoDefault(payload.user);
    state = AsyncValue.data(AuthState.authenticated(
      payload.user,
      payload.token,
      payload.defaultFilter,
    ));
    // Push registration is driven by the auth-listener in `MyApp.build` so
    // both cold-start verification and interactive login flow through the
    // same code path. Calling `onAuthenticated` here would double-fire it.
  }

  Future<void> registerStudent(
      String login, String password, int groupId) async {
    final store = ref.read(tokenStoreProvider);
    final client = ref.read(graphqlClientProvider);
    final r = await client
        .mutate(MutationOptions(
          document: gql(registerStudentMutation),
          variables: {
            'login': login,
            'password': password,
            'groupId': groupId,
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ))
        .timeout(const Duration(seconds: 10));
    if (r.hasException) {
      throw r.exception!;
    }
    final regRaw = r.data!['registerStudent'] as Map<String, dynamic>;
    final payload = LoginPayload.fromJson(regRaw);
    await store.save(payload.token);
    final userRaw = regRaw['user'];
    if (userRaw is Map<String, dynamic>) {
      unawaited(ref.read(cachedIdentityStoreProvider).save(userRaw));
    }
    ref.read(authEpochProvider.notifier).bump();
    _applyDefaultFilter(payload.defaultFilter);
    _applyStudentGroupAutoDefault(payload.user);
    state = AsyncValue.data(AuthState.authenticated(
      payload.user,
      payload.token,
      payload.defaultFilter,
    ));
    // Push registration is handled by the auth-listener in `MyApp.build`.
  }

  Future<void> logout() async {
    // Clear local state immediately so UI responds without waiting for the
    // network. Push de-register and token clear happen in the background.
    state = const AsyncValue.data(AuthState.guest());
    ref.read(scheduleFiltersProvider.notifier).clear();
    ref.read(authEpochProvider.notifier).bump();
    // Synchronous state update — persisted asynchronously.
    ref.read(guestModeChosenProvider.notifier).clear();
    final store = ref.read(tokenStoreProvider);
    final identityStore = ref.read(cachedIdentityStoreProvider);
    final container = ref.container;
    unawaited(() async {
      try {
        await push.onLogout(container);
      } catch (_) {}
      try {
        await store.clear();
      } catch (_) {}
      try {
        await identityStore.clear();
      } catch (_) {}
    }());
  }

  Future<void> setAccentColor(String? hex) async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.mutate(MutationOptions(
      document: gql(setAccentColorMutation),
      variables: {'color': hex},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) {
      throw _messageFromException(r.exception!);
    }
    final raw = r.data?['setAccentColor'];
    if (raw == null) return;
    final meMap = raw as Map<String, dynamic>;
    final user = AppUser.fromJson(meMap);
    final current = state.asData?.value;
    final token = current?.token;
    if (token == null) return;
    unawaited(ref.read(cachedIdentityStoreProvider).save(meMap));
    state = AsyncValue.data(AuthState.authenticated(
      user,
      token,
      current?.defaultFilter ?? const ScheduleDefaultFilter(),
    ));
  }

  Future<void> refreshMe() async {
    final client = ref.read(graphqlClientProvider);
    final r = await client.query(QueryOptions(
      document: gql(meQuery),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (r.hasException) {
      await handleAuthOpFailure(r.exception!);
      return;
    }
    final raw = r.data?['me'];
    if (raw == null) return;
    final meMap = raw as Map<String, dynamic>;
    final user = AppUser.fromJson(meMap);
    final current = state.asData?.value;
    final token = current?.token;
    if (token == null) return;
    unawaited(ref.read(cachedIdentityStoreProvider).save(meMap));
    state = AsyncValue.data(AuthState.authenticated(
      user,
      token,
      current?.defaultFilter ?? const ScheduleDefaultFilter(),
    ));
  }

  /// Called when an authed operation returns unauthorized. Clears the
  /// invalid token and signals the UI so it can tell the user.
  Future<void> handleSessionExpired() async {
    final current = state.asData?.value;
    // Only meaningful if we thought we were authenticated.
    if (current == null || !current.isAuthenticated) return;
    final store = ref.read(tokenStoreProvider);
    await store.clear();
    // Wipe the cached identity too — keeping it would let the next cold
    // start re-seed an authenticated UI from a token-less store and only
    // notice the mismatch when the background refresh fired.
    await ref.read(cachedIdentityStoreProvider).clear();
    ref.read(scheduleFiltersProvider.notifier).clear();
    ref.read(authEpochProvider.notifier).bump();
    ref.read(sessionExpiredProvider.notifier).signal();
    ref.read(backendUnreachableProvider.notifier).clear();
    state = const AsyncValue.data(AuthState.guest());
  }

  /// Classifies a failed authed operation and routes it to the right
  /// handler: unauthorized triggers a session-expiry logout, transport
  /// failure triggers the "backend unreachable" overlay without logging
  /// the user out.
  Future<void> handleAuthOpFailure(OperationException e) async {
    if (looksUnauthorized(e)) {
      await handleSessionExpired();
      return;
    }
    if (looksLikeBackendUnreachable(e)) {
      // Lifecycle gate: only surface the overlay when the app is currently
      // foregrounded. A failure that arrives while paused/inactive is not
      // actionable to the user — and if we set the provider anyway, the
      // overlay flashes onto the screen the moment the user resumes,
      // before the auto-retry path has a chance to clear it.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        return;
      }
      // Resume grace: drop errors that fire in the first 1.5s after a
      // resume. Android tears down the socket layer while backgrounded;
      // the first request after resume often loses the DNS race and
      // self-heals on the next attempt before the overlay would help.
      final resumedAt = ref.read(resumedAtProvider);
      if (resumedAt != null &&
          DateTime.now().difference(resumedAt) <
              const Duration(milliseconds: 1500)) {
        return;
      }
      ref
          .read(backendUnreachableProvider.notifier)
          .set(_networkErrorMessage(e));
    }
  }

  /// Server-suggested default filter (group/teacher). Applied only when the
  /// user has no saved filter selection — the saved choice from prefs (1.3.2
  /// item 2b) wins so logging back in doesn't overwrite a custom pick.
  void _applyDefaultFilter(ScheduleDefaultFilter f) {
    if (f.isEmpty) return;
    final notifier = ref.read(scheduleFiltersProvider.notifier);
    final current = ref.read(scheduleFiltersProvider);
    if (!current.isEmpty) return;
    if (f.groupIds.isNotEmpty) notifier.setGroup(f.groupIds.first);
    if (f.teacherIds.isNotEmpty) notifier.setTeacher(f.teacherIds.first);
  }

  /// 1.3.2 Item 2a: students get their own group as the default filter when
  /// nothing is saved yet. Fires after [_applyDefaultFilter] as a safety-net
  /// for the case where the server didn't echo a defaultFilter — without it,
  /// a fresh-install student would land on an empty schedule view until they
  /// hand-picked their group from the filter dropdown.
  void _applyStudentGroupAutoDefault(AppUser user) {
    if (user.role != UserRole.student) return;
    final groupId = user.groupId;
    if (groupId == null) return;
    final current = ref.read(scheduleFiltersProvider);
    if (!current.isEmpty) return;
    ref.read(scheduleFiltersProvider.notifier).setGroup(groupId);
  }
}

final authProvider = AsyncNotifierProvider<Auth, AuthState>(Auth.new);

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).asData?.value.user;
});

String _messageFromException(OperationException e) {
  if (e.graphqlErrors.isNotEmpty) {
    return e.graphqlErrors.first.message;
  }
  final le = e.linkException;
  if (le != null) return le.toString();
  return 'Network error';
}
