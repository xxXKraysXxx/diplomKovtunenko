// 1.3.5 — public formatter for the week-list view's range + parity header.
// Lives in its own library so it can be unit-tested without dragging in
// `ScheduleScreen.dart` (and all of Material). The l10n keys it uses are
// shared with the screen; the month-genitive switch is duplicated here
// to keep the dependency surface tiny.

import '../l10n/generated/app_localizations.dart';
import 'week_math.dart';

/// Formats the week-list header: "{range}, {parity}".
///
/// Picks the right l10n template based on whether the week:
///   - stays within one month  → `weekListRangeSameMonth`
///   - crosses a month boundary → `weekListRangeCrossMonth`
///   - crosses a year boundary  → `weekListRangeCrossYear`
///
/// The parity word is the lowercase feminine form ("чётная" / "нечётная"
/// in Russian; "even" / "odd" in English) — agrees with the implicit
/// noun "неделя" / "week".
///
/// [today] is accepted to leave room for future "show year when distant
/// from today" logic; the current implementation only adds the year on
/// year-crossing weeks per spec ("prefer concise").
String formatWeekRangeWithParity(
  AppLocalizations l10n,
  DateTime monday, {
  required DateTime today,
}) {
  final sunday = monday.add(const Duration(days: 6));
  final parity = isEvenWeek(monday)
      ? l10n.weekListParityEven
      : l10n.weekListParityOdd;
  if (monday.year != sunday.year) {
    return l10n.weekListRangeCrossYear(
      monday.day,
      _monthGen(l10n, monday.month),
      monday.year,
      sunday.day,
      _monthGen(l10n, sunday.month),
      sunday.year,
      parity,
    );
  }
  if (monday.month != sunday.month) {
    return l10n.weekListRangeCrossMonth(
      monday.day,
      _monthGen(l10n, monday.month),
      sunday.day,
      _monthGen(l10n, sunday.month),
      parity,
    );
  }
  return l10n.weekListRangeSameMonth(
    monday.day,
    sunday.day,
    _monthGen(l10n, monday.month),
    parity,
  );
}

String _monthGen(AppLocalizations l10n, int month) {
  return switch (month) {
    1 => l10n.monthGenJan,
    2 => l10n.monthGenFeb,
    3 => l10n.monthGenMar,
    4 => l10n.monthGenApr,
    5 => l10n.monthGenMay,
    6 => l10n.monthGenJun,
    7 => l10n.monthGenJul,
    8 => l10n.monthGenAug,
    9 => l10n.monthGenSep,
    10 => l10n.monthGenOct,
    11 => l10n.monthGenNov,
    _ => l10n.monthGenDec,
  };
}
