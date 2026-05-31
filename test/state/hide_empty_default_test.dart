import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.3.5 Item 3 — `hideEmptySlotsProvider` default flips from false → true
/// for fresh installs and upgraders who never touched the toggle. Users
/// with a saved value (either way) keep their explicit choice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default is true when no pref is stored (1.3.5 fresh-install default)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final value = await c.read(hideEmptySlotsProvider.future);
    expect(value, isTrue);
  });

  test('explicit false is preserved across container reads (upgraders who '
      'turned the toggle off keep their choice)', () async {
    SharedPreferences.setMockInitialValues({'hideEmptySlots': false});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final value = await c.read(hideEmptySlotsProvider.future);
    expect(value, isFalse);
  });

  test('explicit true is preserved (the saved value path also fires for users '
      'who set it on)', () async {
    SharedPreferences.setMockInitialValues({'hideEmptySlots': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final value = await c.read(hideEmptySlotsProvider.future);
    expect(value, isTrue);
  });

  test('set(false) persists across container restart', () async {
    SharedPreferences.setMockInitialValues({});
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    await c1.read(hideEmptySlotsProvider.future);
    await c1.read(hideEmptySlotsProvider.notifier).set(false);
    expect(c1.read(hideEmptySlotsProvider).asData?.value, isFalse);

    // Fresh container reads from the same backing prefs and sees false.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final restarted = await c2.read(hideEmptySlotsProvider.future);
    expect(restarted, isFalse);
  });
}
