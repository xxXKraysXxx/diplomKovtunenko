import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:ncti_schedule_client/api/cached_identity_store.dart';
import 'package:ncti_schedule_client/api/graphql_config.dart';
import 'package:ncti_schedule_client/api/queries.dart';
import 'package:ncti_schedule_client/api/token_store.dart';
import 'package:ncti_schedule_client/state/auth.dart';

/// 1.2.11 Item 1a: cache-first Auth.build(). With a stored token AND a
/// previously-cached `me` payload, build() must return authenticated
/// immediately — no network gate. The background `me` query then runs:
/// - 401 → log the user out (real session expiry).
/// - Network/timeout failure → keep the user authenticated; the offline
///   banner surfaces non-blocking.

const _meSampleStudent = {
  'id': 42,
  'login': 'student42',
  'role': 'STUDENT',
  'groupId': 7,
  'teacherId': null,
  'canPush': true,
  'canBroadcastGlobally': false,
  'accentColor': null,
  'lastActivityAt': '2026-04-01T00:00:00Z',
  'createdAt': '2026-01-01T00:00:00Z',
};

class _FakeCachedIdentityStore extends CachedIdentityStore {
  _FakeCachedIdentityStore({Map<String, dynamic>? seeded})
      : _stored = seeded == null ? null : Map<String, dynamic>.from(seeded),
        super.forTesting();

  Map<String, dynamic>? _stored;

  @override
  Future<Map<String, dynamic>?> load() async => _stored;

  @override
  Future<void> save(Map<String, dynamic> me) async {
    _stored = Map<String, dynamic>.from(me);
  }

  @override
  Future<void> clear() async {
    _stored = null;
  }
}

class _RecordingClient implements GraphQLClient {
  _RecordingClient(this._handler);
  final Future<QueryResult> Function(QueryOptions options) _handler;
  int queryCalls = 0;

  @override
  Future<QueryResult<TParsed>> query<TParsed>(
      QueryOptions<TParsed> options) async {
    queryCalls += 1;
    final result = await _handler(options);
    // Cast — handler returns dynamic-typed QueryResult; tests only inspect
    // the data/exception fields which don't depend on TParsed.
    return result as QueryResult<TParsed>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

QueryResult _ok(Map<String, dynamic> data) {
  final ctx = Context().withEntry(HttpLinkResponseContext(statusCode: 200));
  return QueryResult(
    options: QueryOptions(document: gql(meQuery)),
    data: data,
    source: QueryResultSource.network,
    context: ctx,
  );
}

QueryResult _unauthorized() {
  return QueryResult(
    options: QueryOptions(document: gql(meQuery)),
    exception: OperationException(
      graphqlErrors: [
        const GraphQLError(message: 'Unauthorized', extensions: {
          'code': 'UNAUTHENTICATED',
        }),
      ],
    ),
    source: QueryResultSource.network,
  );
}

QueryResult _networkFailure() {
  return QueryResult(
    options: QueryOptions(document: gql(meQuery)),
    exception: OperationException(
      linkException: NetworkException(
        originalException: const SocketExceptionStub(),
        message: 'Failed host lookup',
        uri: Uri.parse('https://example.invalid/graphql'),
      ),
    ),
    source: QueryResultSource.network,
  );
}

/// Minimal Exception stand-in for the [NetworkException.originalException]
/// slot. graphql_flutter passes it through `toString()` only, so any object
/// whose `toString()` reads like a transport failure satisfies the
/// `looksLikeBackendUnreachable` heuristic.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: Failed host lookup';
}

ProviderContainer _container({
  required _RecordingClient client,
  required _FakeCachedIdentityStore identity,
  required TokenStore tokens,
}) {
  final c = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(tokens),
    cachedIdentityStoreProvider.overrideWithValue(identity),
    graphqlClientProvider.overrideWithValue(client),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth.build cache-first (Item 1a)', () {
    test('cached identity + token → authenticated WITHOUT awaiting network',
        () async {
      // Network "stalls" — completer never fires. If build() awaited it,
      // the test would hang past the 30s default timeout.
      final stalled = Completer<QueryResult>();
      final client = _RecordingClient((_) => stalled.future);
      final identity = _FakeCachedIdentityStore(seeded: _meSampleStudent);
      final tokens = TokenStore.forTesting(initial: 'cached-token');
      final c = _container(
          client: client, identity: identity, tokens: tokens);

      // The future from .future resolves with the seeded auth state — the
      // cached identity, NOT the (still-pending) network response.
      final state = await c.read(authProvider.future).timeout(
            const Duration(seconds: 2),
            onTimeout: () =>
                fail('build() should not block on the network when cached'),
          );

      expect(state.isAuthenticated, isTrue);
      expect(state.user?.id, 42);
      expect(state.user?.login, 'student42');
      expect(state.token, 'cached-token');
      // No banner — the cached path is "happy path" until the background
      // refresh proves otherwise.
      expect(c.read(backendUnreachableProvider), isNull);

      stalled.complete(_ok({'me': _meSampleStudent}));
    });

    test('cached identity + 401 in background → logs out + signals expiry',
        () async {
      final client = _RecordingClient((_) async => _unauthorized());
      final identity = _FakeCachedIdentityStore(seeded: _meSampleStudent);
      final tokens = TokenStore.forTesting(initial: 'expired-token');
      final c = _container(
          client: client, identity: identity, tokens: tokens);

      // Cache-first auth resolves immediately.
      final initial = await c.read(authProvider.future);
      expect(initial.isAuthenticated, isTrue);

      // Wait for the background refresh to fire and process the 401.
      // The background query is unawaited, so we yield until the state
      // flips to guest or a few microtasks have run.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (!(c.read(authProvider).asData?.value.isAuthenticated ?? true)) {
          break;
        }
      }

      final after = c.read(authProvider).asData?.value;
      expect(after, isNotNull);
      expect(after!.isAuthenticated, isFalse,
          reason: 'a confirmed 401 must boot the user back to guest');
      expect(c.read(sessionExpiredProvider), greaterThan(0),
          reason: 'session-expiry pulse should fire so the UI snackbar shows');
    });

    test(
        'cached identity + network failure → KEEPS authenticated, '
        'no logout (banner surfaces via handleAuthOpFailure)', () async {
      final client = _RecordingClient((_) async => _networkFailure());
      final identity = _FakeCachedIdentityStore(seeded: _meSampleStudent);
      final tokens = TokenStore.forTesting(initial: 'still-valid-token');
      final c = _container(
          client: client, identity: identity, tokens: tokens);

      final initial = await c.read(authProvider.future);
      expect(initial.isAuthenticated, isTrue);

      // Let the background refresh attempt + fail land.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final after = c.read(authProvider).asData?.value;
      expect(after, isNotNull);
      expect(after!.isAuthenticated, isTrue,
          reason: 'a network failure must NEVER eject the user from cached UI');
      expect(after.token, 'still-valid-token');
    });

    test('cached identity + successful refresh → updates user payload',
        () async {
      // Simulate the user updating their accent color server-side: the
      // background refresh should propagate the new value.
      final updated = Map<String, dynamic>.from(_meSampleStudent)
        ..['accentColor'] = '#FF8800';
      final client = _RecordingClient((_) async => _ok({'me': updated}));
      final identity = _FakeCachedIdentityStore(seeded: _meSampleStudent);
      final tokens = TokenStore.forTesting(initial: 'still-valid-token');
      final c = _container(
          client: client, identity: identity, tokens: tokens);

      final initial = await c.read(authProvider.future);
      expect(initial.user?.accentColor, isNull);

      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (c.read(authProvider).asData?.value.user?.accentColor != null) {
          break;
        }
      }

      expect(c.read(authProvider).asData?.value.user?.accentColor, '#FF8800');
    });
  });
}
