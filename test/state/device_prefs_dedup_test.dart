import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/device_prefs.dart';

/// Item 6 of 1.2.10: SettingScreen used to call
/// [DevicePrefsNotifier.refresh] on every mount, firing a `devicePushPrefs`
/// query for each tab-switch / drag-down dismiss. The TTL inside
/// [DevicePrefsNotifier.refresh] now deduplicates within
/// [kDevicePrefsRefreshTtl] so a remount inside the window is a no-op.
class _FakeDevicePrefsNotifier extends DevicePrefsNotifier {
  int fetchCalls = 0;

  @override
  Future<DevicePrefs?> build() async {
    // Bypass the FCM-token watch and the in-build network kick. Tests that
    // need a token use [refresh] directly with the fake notifier seeded.
    return null;
  }

  @override
  Future<void> fetchPrefsForToken(String token) async {
    fetchCalls += 1;
    // Simulate the timestamp the production fetch would stamp on success
    // so subsequent refresh() calls see a recent fetch and dedup.
    markFetchedAtForTesting(DateTime.now());
  }
}

class _CurrentFcmTokenStub extends CurrentFcmTokenNotifier {
  _CurrentFcmTokenStub(this._initial);
  final String? _initial;

  @override
  String? build() => _initial;
}

({ProviderContainer container, _FakeDevicePrefsNotifier fake})
    _setup({String? token}) {
  final fake = _FakeDevicePrefsNotifier();
  final c = ProviderContainer(overrides: [
    currentFcmTokenProvider
        .overrideWith(() => _CurrentFcmTokenStub(token ?? 'test-token')),
    devicePrefsProvider.overrideWith(() => fake),
  ]);
  addTearDown(c.dispose);
  return (container: c, fake: fake);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DevicePrefsNotifier.refresh dedup', () {
    test(
        'simulated remount within TTL does not trigger a second fetch '
        '(Item 6 acceptance)', () async {
      final s = _setup();
      // Trigger build so the notifier is ready.
      await s.container.read(devicePrefsProvider.future);

      // First refresh — analogous to the user opening Settings the first
      // time. Hits the network (the fake counter increments).
      await s.container.read(devicePrefsProvider.notifier).refresh();
      expect(s.fake.fetchCalls, 1);

      // Second refresh fires immediately — the user dismisses Settings
      // and opens it again. Inside the TTL: must be a no-op.
      await s.container.read(devicePrefsProvider.notifier).refresh();
      expect(s.fake.fetchCalls, 1,
          reason: 'remount inside TTL must not re-query the server');

      // Third refresh, also inside TTL. Still no-op.
      await s.container.read(devicePrefsProvider.notifier).refresh();
      expect(s.fake.fetchCalls, 1);
    });

    test('refresh past the TTL re-fetches', () async {
      final s = _setup();
      await s.container.read(devicePrefsProvider.future);

      await s.container.read(devicePrefsProvider.notifier).refresh();
      expect(s.fake.fetchCalls, 1);

      // Rewind the dedup timestamp past the TTL boundary — simulates the
      // user coming back to Settings hours later.
      s.fake.markFetchedAtForTesting(
        DateTime.now().subtract(kDevicePrefsRefreshTtl * 2),
      );

      await s.container.read(devicePrefsProvider.notifier).refresh();
      expect(s.fake.fetchCalls, 2,
          reason: 'past-TTL refresh should re-query the server');
    });

    test('refresh with no token is a no-op (does not fetch)', () async {
      final s = _setup(token: '');
      await s.container.read(devicePrefsProvider.future);

      await s.container.read(devicePrefsProvider.notifier).refresh();
      expect(s.fake.fetchCalls, 0);
    });
  });
}
