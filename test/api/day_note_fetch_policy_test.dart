import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:ncti_schedule_client/api/graphql_config.dart';
import 'package:ncti_schedule_client/api/offline_json_cache_store.dart';
import 'package:ncti_schedule_client/api/queries.dart';
import 'package:ncti_schedule_client/api/raspisanie_repository.dart';
import 'package:ncti_schedule_client/api/schedule_cache_store.dart';
import 'package:ncti_schedule_client/state/schedule_filters.dart';

/// 1.3.8 Item 1: regression where adding/editing a day note didn't appear
/// until cold restart.
///
/// Root cause: `fetchDayNote` used `FetchPolicy.cacheAndNetwork`. With
/// graphql 5.2.4, `client.query()` resolves with the cache hit when the
/// cache has data; the network leg refreshes the store in the background but
/// doesn't update the awaited Future. The dialog's
/// `ref.invalidate(dayNoteProvider(d))` after `setDayNote` then re-runs the
/// provider against that stale cache, so the UI shows the OLD note until
/// the next cold start (when the network-refreshed cache is read fresh).
///
/// Fix: prefer `networkOnly`; fall back to the explicit offline cache only on
/// a transport failure. Verified end-to-end: post-mutation reads always go to
/// the wire and reflect the freshly-written body.

class _FakeClient implements GraphQLClient {
  _FakeClient();

  /// Per-policy queue of canned responses. Tests `add` to whichever policy
  /// the call should hit; the call pops the front.
  final Map<FetchPolicy, List<QueryResult>> _queue = {
    FetchPolicy.networkOnly: [],
    FetchPolicy.cacheOnly: [],
  };

  /// Recorded order of fetch policies, oldest first. Tests assert
  /// `policies` to confirm networkOnly is the first wire attempt.
  final List<FetchPolicy> policies = [];

  void enqueueNetwork(QueryResult r) => _queue[FetchPolicy.networkOnly]!.add(r);
  void enqueueCache(QueryResult r) => _queue[FetchPolicy.cacheOnly]!.add(r);

  @override
  Future<QueryResult<TParsed>> query<TParsed>(
      QueryOptions<TParsed> options) async {
    final policy = options.fetchPolicy ?? FetchPolicy.cacheAndNetwork;
    policies.add(policy);
    final pending = _queue[policy];
    if (pending == null || pending.isEmpty) {
      fail('no canned QueryResult queued for $policy');
    }
    return pending.removeAt(0) as QueryResult<TParsed>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleCacheStore implements ScheduleCacheStore {
  final Map<String, List<Map<String, dynamic>>> _rows = {};

  void seed(ScheduleCacheKey key, List<Map<String, dynamic>> rows) {
    _rows[key.cacheId] = _cloneRows(rows);
  }

  @override
  Future<List<Map<String, dynamic>>?> read(ScheduleCacheKey key) async {
    final rows = _rows[key.cacheId];
    return rows == null ? null : _cloneRows(rows);
  }

  @override
  Future<void> write(
      ScheduleCacheKey key, List<Map<String, dynamic>> rows) async {
    seed(key, rows);
  }

  @override
  Future<void> clear() async => _rows.clear();

  static List<Map<String, dynamic>> _cloneRows(
    List<Map<String, dynamic>> rows,
  ) =>
      rows.map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
}

class _FakeOfflineJsonCacheStore implements OfflineJsonCacheStore {
  final Map<String, List<Map<String, dynamic>>> _rows = {};
  final Map<String, Map<String, dynamic>> _objects = {};

  void seedRows(String key, List<Map<String, dynamic>> rows) {
    _rows[key] = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  void seedObject(String key, Map<String, dynamic> object) {
    _objects[key] = Map<String, dynamic>.from(object);
  }

  @override
  Future<List<Map<String, dynamic>>?> readRows(String key) async {
    return _rows[key]
        ?.map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  Future<void> writeRows(String key, List<Map<String, dynamic>> rows) async {
    seedRows(key, rows);
  }

  @override
  Future<Map<String, dynamic>?> readObject(String key) async {
    final object = _objects[key];
    return object == null ? null : Map<String, dynamic>.from(object);
  }

  @override
  Future<void> writeObject(String key, Map<String, dynamic> object) async {
    seedObject(key, object);
  }

  @override
  Future<void> remove(String key) async {
    _objects.remove(key);
    _rows.remove(key);
  }

  @override
  Future<void> removeByKeyPrefix(String prefix) async {
    _objects.removeWhere((key, _) => key.startsWith(prefix));
    _rows.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clear() async {
    _objects.clear();
    _rows.clear();
  }
}

QueryResult _ok(Map<String, dynamic> data) {
  final ctx = Context().withEntry(HttpLinkResponseContext(statusCode: 200));
  return QueryResult(
    options: QueryOptions(document: gql(dayNoteQuery)),
    data: data,
    source: QueryResultSource.network,
    context: ctx,
  );
}

QueryResult _networkFailure() {
  return QueryResult(
    options: QueryOptions(document: gql(dayNoteQuery)),
    exception: OperationException(
      linkException: NetworkException(
        originalException: const _SocketStub(),
        message: 'Failed host lookup',
        uri: Uri.parse('https://example.invalid/graphql'),
      ),
    ),
    source: QueryResultSource.network,
  );
}

class _SocketStub implements Exception {
  const _SocketStub();
  @override
  String toString() => 'SocketException: Failed host lookup';
}

Map<String, dynamic> _raspRow(String subject) => {
      'date': '2026-05-10',
      'subjectNumber': 1,
      'subgroup': null,
      'classroom': '101',
      'isOverride': false,
      'groupBy': {'id': 42, 'name': 'IS-42'},
      'teacherBy': {'id': 7, 'name': 'Teacher'},
      'subjectBy': {'id': 9, 'name': subject},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fetchDayNote (1.3.8 Item 1)', () {
    test('uses networkOnly so post-mutation reads return fresh data', () async {
      final client = _FakeClient()
        ..enqueueNetwork(_ok({
          'dayNote': {
            'id': 1,
            'date': '2026-04-28',
            'body': 'fresh from server',
            'updatedAt': '2026-04-28T10:00:00Z',
          },
        }));
      final repo = RaspisanieRepository(client);

      final note = await repo.fetchDayNote(DateTime(2026, 4, 28));
      expect(note?.body, 'fresh from server');
      expect(client.policies, [FetchPolicy.networkOnly],
          reason: 'on success the cache leg must NOT fire');
    });

    test('falls back to explicit note cache when network fails', () async {
      final cache = _FakeOfflineJsonCacheStore()
        ..seedObject('dayNote:2026-04-28', {
          'id': 1,
          'date': '2026-04-28',
          'body': 'last seen offline',
          'updatedAt': '2026-04-27T08:00:00Z',
        });
      final client = _FakeClient()..enqueueNetwork(_networkFailure());
      final repo = RaspisanieRepository(client, offlineCache: cache);

      final note = await repo.fetchDayNote(DateTime(2026, 4, 28));
      expect(note?.body, 'last seen offline');
      expect(client.policies, [FetchPolicy.networkOnly],
          reason: 'transport failure must fall through to cache');
    });

    test('rethrows network error when cache is also empty', () async {
      final client = _FakeClient()..enqueueNetwork(_networkFailure());
      final repo = RaspisanieRepository(client);

      await expectLater(
        repo.fetchDayNote(DateTime(2026, 4, 28)),
        throwsA(isA<OperationException>()),
      );
      expect(client.policies, [FetchPolicy.networkOnly]);
    });

    test('returns null when the server reports no note (not an error)',
        () async {
      final client = _FakeClient()..enqueueNetwork(_ok({'dayNote': null}));
      final repo = RaspisanieRepository(client);

      final note = await repo.fetchDayNote(DateTime(2026, 4, 28));
      expect(note, isNull);
      expect(client.policies, [FetchPolicy.networkOnly]);
    });
  });

  group('fetchDayNotesRange (1.3.8 Item 1, range overlay)', () {
    test('uses networkOnly so the schedule grid reflects fresh edits',
        () async {
      final client = _FakeClient()
        ..enqueueNetwork(_ok({
          'dayNotes': [
            {
              'id': 1,
              'date': '2026-04-28',
              'body': 'a',
              'updatedAt': '2026-04-28T10:00:00Z',
            },
            {
              'id': 2,
              'date': '2026-04-29',
              'body': 'b',
              'updatedAt': '2026-04-28T11:00:00Z',
            },
          ],
        }));
      final repo = RaspisanieRepository(client);

      final notes = await repo.fetchDayNotesRange(
          DateTime(2026, 4, 1), DateTime(2026, 4, 30));
      expect(notes, hasLength(2));
      expect(client.policies, [FetchPolicy.networkOnly]);
    });

    test('falls back to cache on transport failure', () async {
      final cache = _FakeOfflineJsonCacheStore()
        ..seedRows('dayNotes:2026-04-01:2026-04-30', const []);
      final client = _FakeClient()..enqueueNetwork(_networkFailure());
      final repo = RaspisanieRepository(client, offlineCache: cache);

      final notes = await repo.fetchDayNotesRange(
          DateTime(2026, 4, 1), DateTime(2026, 4, 30));
      expect(notes, isEmpty);
      expect(client.policies, [FetchPolicy.networkOnly]);
    });
  });

  group('fetch raspisanie (schedule freshness)', () {
    test('uses networkOnly by default so cold start paints fresh schedule',
        () async {
      final client = _FakeClient()
        ..enqueueNetwork(_ok({
          'raspisanie': [_raspRow('Fresh subject')],
        }));
      final repo = RaspisanieRepository(client);

      final rows = await repo.fetch(groupIds: const [42]);

      expect(rows.single.subject.name, 'Fresh subject');
      expect(client.policies, [FetchPolicy.networkOnly],
          reason: 'schedule reads must not resolve from stale cache first');
    });

    test('falls back to bounded schedule cache when network fetch fails',
        () async {
      final cache = _FakeScheduleCacheStore()
        ..seed(
          ScheduleCacheKey(
            groupIds: const [42],
            from: null,
            to: null,
          ),
          [_raspRow('Last seen offline')],
        );
      final client = _FakeClient()..enqueueNetwork(_networkFailure());
      final repo = RaspisanieRepository(client, scheduleCache: cache);

      final rows = await repo.fetch(groupIds: const [42]);

      expect(rows.single.subject.name, 'Last seen offline');
      expect(client.policies, [FetchPolicy.networkOnly]);
    });

    test('legacy cacheAndNetwork caller is still forced through network first',
        () async {
      final client = _FakeClient()
        ..enqueueNetwork(_ok({'raspisanie': const []}));
      final repo = RaspisanieRepository(client);

      await repo.fetch(
        groupIds: const [42],
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      );

      expect(client.policies, [FetchPolicy.networkOnly]);
    });

    test('month provider paints cache first, then repaints after network',
        () async {
      final client = _FakeClient()
        ..enqueueNetwork(_ok({
          'raspisanie': [_raspRow('Fresh subject')],
        }));
      final cache = _FakeScheduleCacheStore()
        ..seed(
          ScheduleCacheKey(
            groupIds: const [42],
            from: _iso(gridStartFor(DateTime(2026, 5))),
            to: _iso(gridEndFor(DateTime(2026, 5))),
          ),
          [_raspRow('Cached subject')],
        );
      final container = ProviderContainer(
        overrides: [
          graphqlClientProvider.overrideWithValue(client),
          scheduleCacheStoreProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final params = (
        month: DateTime(2026, 5),
        groupId: 42,
        teacherId: null,
        classroom: null,
      );

      final first =
          await container.read(monthRaspisanieByMonthProvider(params).future);
      expect(first.single.subject.name, 'Cached subject');

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final second =
          await container.read(monthRaspisanieByMonthProvider(params).future);
      expect(second.single.subject.name, 'Fresh subject');
      expect(client.policies, [FetchPolicy.networkOnly]);
    });
  });
}

String _iso(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
