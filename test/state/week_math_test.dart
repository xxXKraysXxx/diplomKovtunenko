import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/common/week_math.dart';

/// Acceptance for the public week-math helpers used by the 1.3.0
/// week-list view. The same helpers are also used by the day-strip
/// parity colouring and the shablon-pattern detector — so a regression
/// here would silently flip parity colours across the whole app.
void main() {
  group('mondayOf', () {
    test('Monday at midnight returns itself', () {
      final d = DateTime(2024, 5, 13); // Monday
      expect(d.weekday, DateTime.monday);
      expect(mondayOf(d), DateTime(2024, 5, 13));
    });

    test('Wednesday rolls back to Monday of the same week', () {
      final d = DateTime(2024, 5, 15, 18, 30); // Wed afternoon
      expect(mondayOf(d), DateTime(2024, 5, 13));
    });

    test('Sunday rolls back to the prior Monday (week starts Mon)', () {
      final d = DateTime(2024, 5, 19); // Sunday
      expect(mondayOf(d), DateTime(2024, 5, 13));
    });

    test('crosses month boundary correctly', () {
      // Wednesday 2024-05-01 → Monday 2024-04-29
      final d = DateTime(2024, 5, 1);
      expect(mondayOf(d), DateTime(2024, 4, 29));
    });

    test('crosses year boundary correctly', () {
      // Wednesday 2025-01-01 → Monday 2024-12-30
      final d = DateTime(2025, 1, 1);
      expect(mondayOf(d), DateTime(2024, 12, 30));
    });
  });

  group('sameWeek', () {
    test('Mon and Sun of same week → true', () {
      expect(
        sameWeek(DateTime(2024, 5, 13), DateTime(2024, 5, 19)),
        true,
      );
    });

    test('Sunday and following Monday → false (different week)', () {
      expect(
        sameWeek(DateTime(2024, 5, 19), DateTime(2024, 5, 20)),
        false,
      );
    });

    test('two arbitrary midweek days agree', () {
      expect(
        sameWeek(DateTime(2024, 5, 14, 9), DateTime(2024, 5, 17, 21)),
        true,
      );
    });
  });

  group('isEvenWeek', () {
    // Anchor Monday is 1970-01-05, declared "even".
    test('reference Monday 1970-01-05 is even', () {
      expect(isEvenWeek(DateTime(1970, 1, 5)), true);
    });

    test('one week later is odd', () {
      expect(isEvenWeek(DateTime(1970, 1, 12)), false);
    });

    test('two weeks later is even again', () {
      expect(isEvenWeek(DateTime(1970, 1, 19)), true);
    });

    test('parity is stable across the week (Mon == Sun)', () {
      final mon = DateTime(2024, 5, 13);
      final sun = DateTime(2024, 5, 19);
      expect(isEvenWeek(mon), isEvenWeek(sun));
    });

    test('every Monday in May 2024 alternates parity', () {
      final mondays = [
        DateTime(2024, 4, 29),
        DateTime(2024, 5, 6),
        DateTime(2024, 5, 13),
        DateTime(2024, 5, 20),
        DateTime(2024, 5, 27),
      ];
      final parity = mondays.map(isEvenWeek).toList();
      // Adjacent weeks must always differ in parity.
      for (var i = 1; i < parity.length; i++) {
        expect(parity[i], isNot(parity[i - 1]),
            reason: 'week parity must alternate between '
                'Monday ${mondays[i - 1]} and Monday ${mondays[i]}');
      }
    });
  });
}
