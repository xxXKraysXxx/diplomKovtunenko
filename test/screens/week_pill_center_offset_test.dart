import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/screens/ScheduleScreen.dart';

/// 1.3.7 — fixed-width pill selector. The retry loop in 1.3.6 fought
/// user input because the centring offset was estimated and clamped
/// against an evolving `maxScrollExtent`. Setting `itemExtent` on the
/// ListView makes the math deterministic from frame 1; this test pins
/// that math down so future edits can't regress it back into
/// "approximately centred".
///
/// We intentionally do NOT verify label widths against
/// `kWeekPillItemExtent` here: flutter_test renders text with the
/// Ahem-style fallback font (every glyph is 1em), which over-states
/// real Roboto/Cyrillic widths by ~50%. A test that passes under Ahem
/// would still over-tune the constant for production. The pill-width
/// constant is sized empirically by visual review and a generous
/// `TextOverflow.fade` provides a graceful degradation path if a
/// future locale change pushes a label past the slot.
void main() {
  group('weekPillCenterOffset — pure math', () {
    const itemExtent = 138.0;
    const viewport = 400.0;
    const middleIndex = 52;
    // _kWeekListRange = 52 → 105 items total.
    const itemCount = 105;
    const minExtent = 0.0;
    final maxExtent = itemCount * itemExtent - viewport;

    test('centres item i: i*extent - (viewport - extent) / 2', () {
      final offset = weekPillCenterOffset(
        index: middleIndex,
        itemExtent: itemExtent,
        viewport: viewport,
        minExtent: minExtent,
        maxExtent: maxExtent,
      );
      // 52 * 138 - (400 - 138) / 2 = 7176 - 131 = 7045.
      expect(offset, 7045.0);
    });

    test('clamps to minExtent at index 0 (left edge)', () {
      // Index 0 raw offset is -131; clamps to 0.
      final offset = weekPillCenterOffset(
        index: 0,
        itemExtent: itemExtent,
        viewport: viewport,
        minExtent: minExtent,
        maxExtent: maxExtent,
      );
      expect(offset, 0.0);
    });

    test('clamps to maxExtent at the last index (right edge)', () {
      final offset = weekPillCenterOffset(
        index: itemCount - 1,
        itemExtent: itemExtent,
        viewport: viewport,
        minExtent: minExtent,
        maxExtent: maxExtent,
      );
      expect(offset, maxExtent);
    });

    test('handles a tiny viewport (smaller than extent) without NaN', () {
      final offset = weekPillCenterOffset(
        index: 10,
        itemExtent: itemExtent,
        viewport: 100,
        minExtent: 0,
        maxExtent: 100000,
      );
      // 10*138 - (100-138)/2 = 1380 - (-19) = 1399.
      expect(offset, 1399.0);
      expect(offset.isFinite, isTrue);
    });

    test('returns a double (not int via clamp)', () {
      // dart:core's `num.clamp` returns `num`; the wrapper must yield
      // `double` so callers can pass directly to `controller.jumpTo`.
      final offset = weekPillCenterOffset(
        index: middleIndex,
        itemExtent: itemExtent,
        viewport: viewport,
        minExtent: minExtent,
        maxExtent: maxExtent,
      );
      expect(offset, isA<double>());
    });

    test('mid-list selection is symmetrically centred for any extent', () {
      // Sweep a few extents to lock in the formula's invariance.
      for (final ext in [100.0, 138.0, 200.0]) {
        final raw = weekPillCenterOffset(
          index: 50,
          itemExtent: ext,
          viewport: 400,
          minExtent: 0,
          maxExtent: 1e9,
        );
        // After scrolling by `raw`, item 50's centre should land at
        // viewport/2 = 200. Item 50's centre in content coords is
        // 50*ext + ext/2; in viewport coords that's (50*ext + ext/2) - raw.
        final itemCentreInViewport = 50 * ext + ext / 2 - raw;
        expect(itemCentreInViewport, closeTo(200.0, 1e-9),
            reason: 'extent=$ext should centre item 50 at viewport/2');
      }
    });
  });
}
