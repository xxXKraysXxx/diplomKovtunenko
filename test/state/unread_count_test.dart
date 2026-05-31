import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/notifications.dart';

/// Skips network fetch in `build()` so we can drive the in-memory counter
/// methods (incrementForPush / decrement) under test. The methods under
/// test are pure local state mutations on `state`; bypassing the network
/// keeps the test hermetic and fast.
class _FakeUnreadCount extends UnreadCount {
  @override
  Future<int> build() async => 0;
}

ProviderContainer _container() {
  final c = ProviderContainer(overrides: [
    unreadCountProvider.overrideWith(_FakeUnreadCount.new),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnreadCount.incrementForPush', () {
    test('starts at 0 after build', () async {
      final c = _container();
      // Trigger build.
      await c.read(unreadCountProvider.future);
      expect(c.read(unreadCountProvider).asData?.value, 0);
    });

    test('increments by 1 per call', () async {
      final c = _container();
      await c.read(unreadCountProvider.future);
      final n = c.read(unreadCountProvider.notifier);
      n.incrementForPush();
      n.incrementForPush();
      n.incrementForPush();
      expect(c.read(unreadCountProvider).asData?.value, 3);
    });
  });

  group('UnreadCount.decrement', () {
    test('decrements by 1', () async {
      final c = _container();
      await c.read(unreadCountProvider.future);
      final n = c.read(unreadCountProvider.notifier);
      n.incrementForPush();
      n.incrementForPush();
      n.decrement();
      expect(c.read(unreadCountProvider).asData?.value, 1);
    });

    test('clamps to 0 (cannot go negative)', () async {
      final c = _container();
      await c.read(unreadCountProvider.future);
      final n = c.read(unreadCountProvider.notifier);
      n.decrement();
      n.decrement();
      n.decrement();
      expect(c.read(unreadCountProvider).asData?.value, 0);
    });

    test('clamp survives repeated decrement past zero', () async {
      final c = _container();
      await c.read(unreadCountProvider.future);
      final n = c.read(unreadCountProvider.notifier);
      n.incrementForPush();
      n.decrement();
      n.decrement();
      n.decrement();
      expect(c.read(unreadCountProvider).asData?.value, 0);
      n.incrementForPush();
      expect(c.read(unreadCountProvider).asData?.value, 1);
    });
  });

  group('UnreadCount.clear', () {
    test('sets the badge to zero', () async {
      final c = _container();
      await c.read(unreadCountProvider.future);
      final n = c.read(unreadCountProvider.notifier);
      n.incrementForPush();
      n.incrementForPush();
      n.clear();
      expect(c.read(unreadCountProvider).asData?.value, 0);
    });
  });
}
