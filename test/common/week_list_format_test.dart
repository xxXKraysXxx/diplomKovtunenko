import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/common/week_list_format.dart';
import 'package:ncti_schedule_client/common/week_math.dart';
import 'package:ncti_schedule_client/l10n/generated/app_localizations.dart';
import 'package:ncti_schedule_client/l10n/generated/app_localizations_en.dart';
import 'package:ncti_schedule_client/l10n/generated/app_localizations_ru.dart';

/// 1.3.5 Item 1 — sticky range + parity header in the week-list view.
/// Validates the three template branches (same-month, cross-month,
/// cross-year) plus the parity label mapping for both shipping locales.
///
/// The reference Monday in `lib/common/week_math.dart` is 1970-01-05; the
/// expected parity word is derived from `isEvenWeek()` so the test stays
/// stable across any future anchor moves (which the project explicitly
/// forbids — but defence-in-depth is cheap).
void main() {
  // 2024-04-01 is a Monday (2024 is a leap year, 2024-01-01 is Mon, +91 days
  // lands on 2024-04-01 also Mon). Picked because it makes "1 апреля –
  // 7 апреля" land in real same-month form.
  final mondayApr1 = DateTime(2024, 4, 1);
  // 2024-04-29 (Monday) → Sunday 2024-05-05. Crosses Apr→May within 2024.
  final mondayApr29 = DateTime(2024, 4, 29);
  // 2024-12-30 (Monday) → Sunday 2025-01-05. Crosses 2024→2025.
  final mondayDec30 = DateTime(2024, 12, 30);

  group('Russian — formatWeekRangeWithParity', () {
    final l10n = AppLocalizationsRu();
    final today = DateTime(2026, 4, 28);

    String parityRu(DateTime monday) =>
        isEvenWeek(monday) ? l10n.weekListParityEven : l10n.weekListParityOdd;

    test('same-month range — "1 апреля – 7 апреля, …"', () {
      final out = formatWeekRangeWithParity(l10n, mondayApr1, today: today);
      expect(out, '1 апреля – 7 апреля, ${parityRu(mondayApr1)}');
      // Strict en-dash, no hyphen.
      expect(out, isNot(contains('-')));
      // Same month name appears twice for same-month weeks.
      expect('апреля'.allMatches(out).length, 2);
    });

    test('cross-month range — "29 апреля – 5 мая, …"', () {
      final out = formatWeekRangeWithParity(l10n, mondayApr29, today: today);
      expect(out, '29 апреля – 5 мая, ${parityRu(mondayApr29)}');
      expect(out, isNot(contains('-')));
      // No year shown for same-year cross-month weeks (concise).
      expect(out, isNot(contains('2024')));
    });

    test('cross-year range — "30 декабря 2024 – 5 января 2025, …"', () {
      final out = formatWeekRangeWithParity(l10n, mondayDec30, today: today);
      expect(out,
          '30 декабря 2024 – 5 января 2025, ${parityRu(mondayDec30)}');
      expect(out, isNot(contains('-')));
    });

    test('parity label maps even week → "чётная"', () {
      // 1970-01-05 is the anchor Monday and even by definition.
      final monday = DateTime(1970, 1, 5);
      expect(isEvenWeek(monday), isTrue);
      final out = formatWeekRangeWithParity(l10n, monday, today: monday);
      expect(out, endsWith(', чётная'));
    });

    test('parity label maps odd week → "нечётная"', () {
      // 1970-01-12 is one week after the anchor → odd.
      final monday = DateTime(1970, 1, 12);
      expect(isEvenWeek(monday), isFalse);
      final out = formatWeekRangeWithParity(l10n, monday, today: monday);
      expect(out, endsWith(', нечётная'));
    });
  });

  group('English — formatWeekRangeWithParity', () {
    final AppLocalizations l10n = AppLocalizationsEn();
    final today = DateTime(2026, 4, 28);

    test('same-month range uses month name twice', () {
      final out = formatWeekRangeWithParity(l10n, mondayApr1, today: today);
      expect(out, startsWith('April 1 – April 7,'));
      expect('April'.allMatches(out).length, 2);
    });

    test('cross-year range includes both years', () {
      final out = formatWeekRangeWithParity(l10n, mondayDec30, today: today);
      expect(out, contains('December 30, 2024'));
      expect(out, contains('January 5, 2025'));
    });

    test('parity label is "even" / "odd" lowercase', () {
      final outEven = formatWeekRangeWithParity(
        l10n,
        DateTime(1970, 1, 5),
        today: DateTime(1970, 1, 5),
      );
      final outOdd = formatWeekRangeWithParity(
        l10n,
        DateTime(1970, 1, 12),
        today: DateTime(1970, 1, 12),
      );
      expect(outEven, endsWith(', even'));
      expect(outOdd, endsWith(', odd'));
    });
  });
}
