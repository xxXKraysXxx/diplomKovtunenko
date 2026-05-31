import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Acceptance for the 1.3.0 schedule-view tri-state setting.
///
/// - Default for new installs is `grid` (no prefs key yet, no legacy bool).
/// - Existing 1.1.1+ users with the legacy `show_week_carousel = true`
///   bool keep their day-strip choice without a re-pick.
/// - Setting any value writes the new key and survives reload.
/// - All three enum values round-trip through the persistence layer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('default is grid when no prefs are present', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final mode = await c.read(scheduleViewModeProvider.future);
    expect(mode, ScheduleViewMode.grid);
  });

  test('legacy show_week_carousel=true migrates to dayStrip on first read',
      () async {
    SharedPreferences.setMockInitialValues({'show_week_carousel': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final mode = await c.read(scheduleViewModeProvider.future);
    expect(mode, ScheduleViewMode.dayStrip);
  });

  test('legacy show_week_carousel=false stays grid', () async {
    SharedPreferences.setMockInitialValues({'show_week_carousel': false});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final mode = await c.read(scheduleViewModeProvider.future);
    expect(mode, ScheduleViewMode.grid);
  });

  test('explicit new key wins over the legacy bool', () async {
    SharedPreferences.setMockInitialValues({
      'show_week_carousel': true,
      'schedule_view_mode': 'weekList',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final mode = await c.read(scheduleViewModeProvider.future);
    expect(mode, ScheduleViewMode.weekList);
  });

  test('set persists and round-trips through SharedPreferences', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Ensure the notifier has built before we mutate it.
    await c.read(scheduleViewModeProvider.future);
    await c
        .read(scheduleViewModeProvider.notifier)
        .set(ScheduleViewMode.weekList);
    expect(c.read(scheduleViewModeProvider).value, ScheduleViewMode.weekList);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('schedule_view_mode'), 'weekList');

    // Build a second container against the same SharedPreferences mock —
    // simulates a relaunch after the user's pick.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final mode = await c2.read(scheduleViewModeProvider.future);
    expect(mode, ScheduleViewMode.weekList);
  });

  test('all three values round-trip', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(scheduleViewModeProvider.future);
    for (final v in ScheduleViewMode.values) {
      await c.read(scheduleViewModeProvider.notifier).set(v);
      expect(c.read(scheduleViewModeProvider).value, v);
    }
  });
}
