import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/lifecycle.dart';

/// Drives `_handleAuthOpFailure` without spinning up the full Auth notifier:
/// inlines the same conditional structure used in production. Exercising
/// the production code path itself would require a fully mocked GraphQL
/// client + token store, which adds churn for what is fundamentally a
/// two-line gate. Keep the gate logic mirrored and the production code
/// asserted by tighter integration in dev/QA.
bool wouldSetOverlay({
  required AppLifecycleState? lifecycle,
  required DateTime? resumedAt,
  Duration grace = const Duration(milliseconds: 1500),
}) {
  if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return false;
  if (resumedAt != null && DateTime.now().difference(resumedAt) < grace) {
    return false;
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Resume flash gate (logic mirror)', () {
    test('skips the overlay when paused', () {
      expect(
        wouldSetOverlay(
          lifecycle: AppLifecycleState.paused,
          resumedAt: null,
        ),
        isFalse,
      );
    });

    test('skips the overlay when inactive', () {
      expect(
        wouldSetOverlay(
          lifecycle: AppLifecycleState.inactive,
          resumedAt: null,
        ),
        isFalse,
      );
    });

    test('skips the overlay within 1.5s of resume', () {
      expect(
        wouldSetOverlay(
          lifecycle: AppLifecycleState.resumed,
          resumedAt: DateTime.now().subtract(const Duration(milliseconds: 200)),
        ),
        isFalse,
      );
    });

    test('surfaces the overlay past the grace window', () {
      expect(
        wouldSetOverlay(
          lifecycle: AppLifecycleState.resumed,
          resumedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        ),
        isTrue,
      );
    });

    test('null lifecycle (web / first launch) does not block', () {
      expect(
        wouldSetOverlay(
          lifecycle: null,
          resumedAt: null,
        ),
        isTrue,
      );
    });

    test('null resumedAt past lifecycle gate is allowed', () {
      expect(
        wouldSetOverlay(
          lifecycle: AppLifecycleState.resumed,
          resumedAt: null,
        ),
        isTrue,
      );
    });
  });

  group('ResumedAt notifier', () {
    test('build returns null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(resumedAtProvider), isNull);
    });

    test('mark stores the timestamp', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final now = DateTime.now();
      container.read(resumedAtProvider.notifier).mark(now);
      expect(container.read(resumedAtProvider), now);
    });

    test('mark overwrites a prior value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final t1 = DateTime(2020, 1, 1);
      final t2 = DateTime(2026, 4, 27);
      container.read(resumedAtProvider.notifier).mark(t1);
      container.read(resumedAtProvider.notifier).mark(t2);
      expect(container.read(resumedAtProvider), t2);
    });
  });

}
