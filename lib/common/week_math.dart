// Week-math helpers used by the 1.3.0 week-list schedule view (and
// gradually by the legacy grid + day-strip code as those callers
// converge). Public so they can be unit-tested without poking at
// private helpers inside `lib/screens/ScheduleScreen.dart`.
//
// Conventions:
// - All inputs are LOCAL DateTime; functions ignore the time-of-day
//   portion. Returned DateTimes are at midnight local.
// - Week starts on Monday (Russian academic convention; matches the
//   existing day-strip + grid behaviour).
// - "Even week" parity is anchored on Monday 1970-01-05 — the reference
//   used elsewhere in the codebase. Anchor change would invalidate
//   shipped V2-F coloring of past weeks, so DO NOT move it.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday at midnight of the local-time week containing [d]. ISO-8601
/// weekday: Monday=1..Sunday=7, so subtracting `weekday-1` walks back
/// to Monday for any input day.
DateTime mondayOf(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - 1));

bool sameWeek(DateTime a, DateTime b) {
  final ma = mondayOf(a);
  final mb = mondayOf(b);
  return ma.year == mb.year && ma.month == mb.month && ma.day == mb.day;
}

bool isEvenWeek(DateTime d) {
  final monday = mondayOf(d);
  // Reference Monday — kept frozen so already-shipped colourings of past
  // weeks don't flip parity in a future build. Anchor change would mean
  // an even-week schedule rendered as 1.2.x would render as odd-week
  // after the bump, which would confuse anyone screen-shotting old terms.
  final ref = DateTime(1970, 1, 5);
  final weeks = monday.difference(ref).inDays ~/ 7;
  return weeks % 2 == 0;
}
