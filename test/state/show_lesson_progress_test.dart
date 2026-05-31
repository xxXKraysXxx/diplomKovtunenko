import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.3.3 Item 6 — `showLessonProgressProvider` toggle controls the
/// in-card progress fill on the currently-running lesson. Default ON
/// preserves historic behaviour for upgraders; OFF surfaces only when the
/// user explicitly flips the new Settings switch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('default is true when no pref is stored (historic behaviour)',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final value = await c.read(showLessonProgressProvider.future);
    expect(value, isTrue);
  });

  test('persists OFF across container restart', () async {
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    await c1.read(showLessonProgressProvider.future);
    await c1.read(showLessonProgressProvider.notifier).set(false);
    expect(c1.read(showLessonProgressProvider).asData?.value, isFalse);

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final value = await c2.read(showLessonProgressProvider.future);
    expect(value, isFalse);
  });

  test('explicit ON also persists', () async {
    SharedPreferences.setMockInitialValues({'show_lesson_progress': false});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(showLessonProgressProvider.future);
    await c.read(showLessonProgressProvider.notifier).set(true);
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final value = await c2.read(showLessonProgressProvider.future);
    expect(value, isTrue);
  });
}
