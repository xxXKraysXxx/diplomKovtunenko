import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/schedule_filters.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.3.2 Item 2b acceptance: schedule filter selection persists across a
/// simulated cold restart. We model "cold restart" by disposing the
/// ProviderContainer and rebuilding a new one against the same primed
/// SharedPreferences handle — the notifier's `build()` reads that handle
/// synchronously, so the second container should hydrate the same filter
/// values that the first one wrote.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduleFilterPrimedPrefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    scheduleFilterPrimedPrefs = null;
  });

  test('default is empty when prefs are blank', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(scheduleFiltersProvider).isEmpty, isTrue);
  });

  test('hydrates groupId from prefs on first read', () async {
    final prefs = scheduleFilterPrimedPrefs!;
    await prefs.setInt(kSchedulePrefGroupId, 42);

    final c = ProviderContainer();
    addTearDown(c.dispose);
    final f = c.read(scheduleFiltersProvider);
    expect(f.groupId, 42);
    expect(f.teacherId, isNull);
    expect(f.classroom, isNull);
  });

  test('setGroup persists to prefs', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(scheduleFiltersProvider.notifier).setGroup(7);
    final prefs = scheduleFilterPrimedPrefs!;
    expect(prefs.getInt(kSchedulePrefGroupId), 7);
  });

  test('setTeacher persists and clears via null', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(scheduleFiltersProvider.notifier).setTeacher(99);
    expect(scheduleFilterPrimedPrefs!.getInt(kSchedulePrefTeacherId), 99);

    c.read(scheduleFiltersProvider.notifier).setTeacher(null);
    expect(scheduleFilterPrimedPrefs!.getInt(kSchedulePrefTeacherId), isNull);
  });

  test('setClassroom persists and clears via null', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(scheduleFiltersProvider.notifier).setClassroom('A-203');
    expect(scheduleFilterPrimedPrefs!.getString(kSchedulePrefClassroom),
        'A-203');

    c.read(scheduleFiltersProvider.notifier).setClassroom(null);
    expect(
        scheduleFilterPrimedPrefs!.getString(kSchedulePrefClassroom), isNull);
  });

  test('clear() wipes all three keys', () async {
    final prefs = scheduleFilterPrimedPrefs!;
    await prefs.setInt(kSchedulePrefGroupId, 1);
    await prefs.setInt(kSchedulePrefTeacherId, 2);
    await prefs.setString(kSchedulePrefClassroom, 'foo');

    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Force notifier build first so its state is hydrated, then clear.
    c.read(scheduleFiltersProvider);
    c.read(scheduleFiltersProvider.notifier).clear();

    expect(prefs.getInt(kSchedulePrefGroupId), isNull);
    expect(prefs.getInt(kSchedulePrefTeacherId), isNull);
    expect(prefs.getString(kSchedulePrefClassroom), isNull);
    expect(c.read(scheduleFiltersProvider).isEmpty, isTrue);
  });

  test('survives a simulated cold restart', () async {
    // Container 1: user picks group 12 + classroom B-100.
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    c1.read(scheduleFiltersProvider.notifier).setGroup(12);
    c1.read(scheduleFiltersProvider.notifier).setClassroom('B-100');
    c1.dispose();

    // Container 2: same prefs, fresh notifier — must rehydrate identical
    // filter without touching the network or login flow.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final f = c2.read(scheduleFiltersProvider);
    expect(f.groupId, 12);
    expect(f.classroom, 'B-100');
    expect(f.teacherId, isNull);
  });
}
