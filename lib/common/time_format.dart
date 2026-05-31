import '../l10n/generated/app_localizations.dart';

/// Returns a locale-aware human-readable string for a duration expressed in
/// whole minutes.
///
/// Rules:
///   < 60 min  → "X min"
///  ≥ 60 min  → "Y hour(s) [Z min]" (trailing minutes omitted when zero)
String formatDuration(AppLocalizations l10n, int totalMinutes) {
  assert(totalMinutes >= 0);
  if (totalMinutes < 60) return l10n.timeMinutesShort(totalMinutes);
  final hours = totalMinutes ~/ 60;
  final mins = totalMinutes % 60;
  if (mins == 0) return l10n.timeHours(hours);
  return l10n.timeHoursMinutes(hours, mins);
}
