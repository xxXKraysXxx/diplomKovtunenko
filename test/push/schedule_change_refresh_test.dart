import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ncti_schedule_client/api/raspisanie_repository.dart';
import 'package:ncti_schedule_client/push/schedule_change_refresh.dart';
import 'package:ncti_schedule_client/state/schedule_filters.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
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

  test('parseScheduleChangePayload decodes backend data shape', () {
    final p = parseScheduleChangePayload({
      'kind': 'raspisanie_changed',
      'group_id': '42',
      'date_min': '2026-05-31',
      'date_max': '2026-06-02',
    });

    expect(p, isNotNull);
    expect(p!.groupId, 42);
    expect(p.from, DateTime(2026, 5, 31));
    expect(p.to, DateTime(2026, 6, 2));
  });

  test('parseScheduleChangePayload ignores unrelated pushes', () {
    expect(parseScheduleChangePayload({'kind': 'announcement'}), isNull);
  });

  test('monthsTouchedByScheduleChange spans inclusive month boundaries', () {
    final months = monthsTouchedByScheduleChange(
      ScheduleChangePayload(
        groupId: 7,
        from: DateTime(2026, 5, 31),
        to: DateTime(2026, 6, 2),
      ),
    );

    expect(months, [DateTime(2026, 5), DateTime(2026, 6)]);
  });

  test('pending background payload round-trips through prefs', () async {
    const original = ScheduleChangePayload(
      groupId: 12,
      from: null,
      to: null,
    );

    await recordPendingScheduleChangePayload(original);
    final first = await takePendingScheduleChangePayload();
    final second = await takePendingScheduleChangePayload();

    expect(first, isNotNull);
    expect(first!.groupId, 12);
    expect(first.from, isNull);
    expect(first.to, isNull);
    expect(second, isNull);
  });

  test('refreshScheduleForChange queues force-network params', () {
    final c = _container();
    c.read(displayedMonthProvider.notifier).set(DateTime(2026, 5, 1));
    c.read(scheduleFiltersProvider.notifier).setTeacher(99);

    refreshScheduleForChange(
      c,
      ScheduleChangePayload(
        groupId: 42,
        from: DateTime(2026, 5, 31),
        to: DateTime(2026, 6, 1),
      ),
    );

    final pending = c.read(scheduleForceRefreshProvider);
    expect(
      pending,
      containsAll(<MonthFilterParams>{
        (
          month: DateTime(2026, 5),
          groupId: null,
          teacherId: 99,
          classroom: null
        ),
        (
          month: DateTime(2026, 6),
          groupId: null,
          teacherId: 99,
          classroom: null
        ),
        (
          month: DateTime(2026, 5),
          groupId: 42,
          teacherId: null,
          classroom: null
        ),
        (
          month: DateTime(2026, 6),
          groupId: 42,
          teacherId: null,
          classroom: null
        ),
      }),
    );
  });
}
