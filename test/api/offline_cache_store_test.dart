import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ncti_schedule_client/api/offline_json_cache_store.dart';
import 'package:ncti_schedule_client/api/schedule_cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('schedule cache key is stable for equivalent filter ordering', () {
    final a = ScheduleCacheKey(
      groupIds: const [3, 1],
      teacherIds: const [9, 2],
      classrooms: const ['302', '101'],
      from: '2026-05-01',
      to: '2026-05-31',
    );
    final b = ScheduleCacheKey(
      groupIds: const [1, 3],
      teacherIds: const [2, 9],
      classrooms: const ['101', '302'],
      from: '2026-05-01',
      to: '2026-05-31',
    );

    expect(a.stableKey, b.stableKey);
    expect(a.cacheId, b.cacheId);
  });

  test('schedule cache evicts least-recently-used entries', () async {
    final store = SharedPrefsScheduleCacheStore(maxEntries: 2);
    final first = ScheduleCacheKey(groupIds: const [1], from: 'a', to: 'b');
    final second = ScheduleCacheKey(groupIds: const [2], from: 'a', to: 'b');
    final third = ScheduleCacheKey(groupIds: const [3], from: 'a', to: 'b');

    await store.write(first, [_row('first')]);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.write(second, [_row('second')]);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.read(first);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.write(third, [_row('third')]);

    expect(await store.read(first), isNotNull);
    expect(await store.read(second), isNull);
    expect(await store.read(third), isNotNull);
  });

  test('default schedule cache keeps current plus adjacent large months',
      () async {
    const store = SharedPrefsScheduleCacheStore();
    final current = ScheduleCacheKey(
        groupIds: const [1], from: '2026-05-01', to: '2026-06-11');
    final previous = ScheduleCacheKey(
        groupIds: const [1], from: '2026-04-01', to: '2026-05-12');
    final next = ScheduleCacheKey(
        groupIds: const [1], from: '2026-06-01', to: '2026-07-12');
    final payload = 'x' * (340 * 1024);

    await store.write(current, [_row('current-$payload')]);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.write(previous, [_row('previous-$payload')]);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.write(next, [_row('next-$payload')]);

    expect(await store.read(current), isNotNull);
    expect(await store.read(previous), isNotNull);
    expect(await store.read(next), isNotNull);
  });

  test('default schedule cache stores a large single month snapshot', () async {
    const store = SharedPrefsScheduleCacheStore();
    final key = ScheduleCacheKey(
        groupIds: const [1], from: '2026-05-01', to: '2026-06-11');
    final payload = 'x' * (600 * 1024);

    await store.write(key, [_row(payload)]);

    expect(await store.read(key), isNotNull);
  });

  test('offline json cache stores rows and objects without shape confusion',
      () async {
    final store = SharedPrefsOfflineJsonCacheStore(maxEntries: 4);

    await store.writeRows('notifications:list', [
      {'id': 1, 'isRead': false},
    ]);
    await store.writeObject('appSettings', {
      'teachersCanBroadcastGlobally': true,
    });

    expect(await store.readRows('notifications:list'), [
      {'id': 1, 'isRead': false},
    ]);
    expect(await store.readObject('appSettings'), {
      'teachersCanBroadcastGlobally': true,
    });
    expect(await store.readObject('notifications:list'), isNull);
    expect(await store.readRows('appSettings'), isNull);
  });
}

Map<String, dynamic> _row(String subject) => {
      'date': '2026-05-10',
      'subjectNumber': 1,
      'subgroup': null,
      'classroom': '101',
      'isOverride': false,
      'groupBy': {'id': 42, 'name': 'IS-42'},
      'teacherBy': {'id': 7, 'name': 'Teacher'},
      'subjectBy': {'id': 9, 'name': subject},
    };
