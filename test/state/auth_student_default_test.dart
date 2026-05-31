import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:ncti_schedule_client/api/cached_identity_store.dart';
import 'package:ncti_schedule_client/api/graphql_config.dart';
import 'package:ncti_schedule_client/api/token_store.dart';
import 'package:ncti_schedule_client/state/auth.dart';
import 'package:ncti_schedule_client/state/schedule_filters.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.3.2 Item 2a acceptance: a STUDENT with a cached identity but no saved
/// schedule filter should land on their own group as the default. A saved
/// filter (Item 2b) wins; non-students get no auto-default.

const _meStudent = {
  'id': 42,
  'login': 'student42',
  'role': 'STUDENT',
  'groupId': 17,
  'teacherId': null,
  'canPush': true,
  'canBroadcastGlobally': false,
  'accentColor': null,
  'lastActivityAt': '2026-04-01T00:00:00Z',
  'createdAt': '2026-01-01T00:00:00Z',
};

const _meTeacher = {
  'id': 99,
  'login': 'teacher99',
  'role': 'TEACHER',
  'groupId': null,
  'teacherId': 5,
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

class _StalledClient implements GraphQLClient {
  @override
  Future<QueryResult<TParsed>> query<TParsed>(
      QueryOptions<TParsed> options) async {
    // Block forever — Auth.build()'s background refresh would otherwise race
    // our assertions. The cached path doesn't await this, so the test
    // proceeds.
    final c = Completer<QueryResult>();
    return await c.future as QueryResult<TParsed>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({
  required Map<String, dynamic>? identity,
  required String? token,
}) {
  final c = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(
      TokenStore.forTesting(initial: token),
    ),
    cachedIdentityStoreProvider.overrideWithValue(
      _FakeCachedIdentityStore(seeded: identity),
    ),
    graphqlClientProvider.overrideWithValue(_StalledClient()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduleFilterPrimedPrefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    scheduleFilterPrimedPrefs = null;
  });

  test(
      'student + no saved filter → auto-defaults to me.groupId on cached-build',
      () async {
    final c = _container(identity: _meStudent, token: 'cached-token');

    final state = await c.read(authProvider.future);
    expect(state.isAuthenticated, isTrue);
    expect(state.user?.role.name, 'student');

    final filters = c.read(scheduleFiltersProvider);
    expect(filters.groupId, 17,
        reason: 'student must default to their own groupId');
    expect(filters.teacherId, isNull);
  });

  test('saved filter wins over auto-default', () async {
    final prefs = scheduleFilterPrimedPrefs!;
    await prefs.setInt(kSchedulePrefGroupId, 99);

    final c = _container(identity: _meStudent, token: 'cached-token');
    await c.read(authProvider.future);

    final filters = c.read(scheduleFiltersProvider);
    expect(filters.groupId, 99,
        reason:
            'saved filter (Item 2b) takes precedence over the auto-default');
  });

  test('non-student does NOT trigger student auto-default', () async {
    final c = _container(identity: _meTeacher, token: 'cached-token');
    await c.read(authProvider.future);

    final filters = c.read(scheduleFiltersProvider);
    expect(filters.isEmpty, isTrue,
        reason:
            'Item 2a only applies to students; teachers/admins keep empty defaults');
  });

  test('student without groupId is left empty', () async {
    final missingGroup = Map<String, dynamic>.from(_meStudent)
      ..['groupId'] = null;
    final c = _container(identity: missingGroup, token: 'cached-token');
    await c.read(authProvider.future);

    final filters = c.read(scheduleFiltersProvider);
    expect(filters.isEmpty, isTrue,
        reason: 'no groupId on the user means we have nothing to default to');
  });
}
