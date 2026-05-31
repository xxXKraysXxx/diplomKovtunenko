import 'dart:convert';

import '../models/raspisanie.dart';
import '../theme/lesson_slots.dart';

/// Brand navy — mirrors `appDefaultSeedLight` in lib/common/theme.dart.
/// Also kept in sync with `WidgetTheme.DEFAULT_ACCENT` on the Kotlin side.
const defaultWidgetAccentHex = '#0B3B7C';

/// SharedPreferences keys that the Android `HomeWidgetProvider` subclasses
/// read. Kept in one place so both sides stay in sync.
class WidgetKeys {
  // Theme
  static const themeAccent = 'widget_theme_accent'; // String, "#rrggbb"
  static const themeDark = 'widget_theme_dark'; // bool

  // CTA: set when the user has no group/teacher/classroom picked. All three
  // providers render a "Выберите группу или преподавателя" state instead of
  // an empty widget when this is true.
  static const ctaMode = 'widget_cta_mode'; // bool

  // Today widget
  static const todayLessons = 'widget_today_lessons'; // JSON array
  static const todayCount = 'widget_today_count';
  static const todayLabel = 'widget_today_label'; // title line
  static const todayDateIso = 'widget_today_date_iso'; // YYYY-MM-DD
  static const todayIsFallback = 'widget_today_is_fallback'; // bool

  // Current-lesson widget — now carries both a "next" and "previous" block so
  // the tall (3×2) mode can show all three rows.
  static const currentState = 'widget_current_lesson_state';
  static const currentSubject = 'widget_current_lesson_subject';
  static const currentRoom = 'widget_current_lesson_room';
  static const currentMinsUntilOrLeft =
      'widget_current_lesson_starts_in_min';
  // Absolute epochs (seconds since unix epoch, stored as string because
  // Android SharedPreferences-via-home_widget doesn't carry 64-bit ints
  // through the plugin. The Kotlin minute-ticker uses these to compute a
  // live "осталось X мин" counter without waking Dart.
  static const currentEndEpochS = 'widget_current_lesson_end_epoch_s';
  static const currentStartEpochS =
      'widget_current_lesson_start_epoch_s';
  // Next lesson (on same day after `now`, or first lesson of the next
  // non-empty day if there's nothing left today). Empty subject = no data.
  static const nextSubject = 'widget_next_lesson_subject';
  static const nextRoom = 'widget_next_lesson_room';
  static const nextLabel = 'widget_next_lesson_label'; // "Далее" / "Завтра"
  // Lesson after `next` — only populated when there's a second upcoming
  // slot on the same day as `next`. Consumed by the 3x3 current-lesson
  // layout.
  static const afterNextSubject = 'widget_after_next_subject';
  static const afterNextRoom = 'widget_after_next_room';
  static const afterNextLabel = 'widget_after_next_label'; // always "Затем"
  // Previous lesson (last slot before `now` on the same day). Empty = none.
  static const prevSubject = 'widget_prev_lesson_subject';
  static const prevRoom = 'widget_prev_lesson_room';
  static const prevLabel = 'widget_prev_lesson_label'; // always "Ранее"

  // Week widget — now carries per-day subject names alongside the count so the
  // cubes can stack 1-3 lesson labels under the weekday header.
  static const weekSummary = 'widget_week_summary'; // JSON array

  // Misc
  static const updatedAt = 'widget_updated_at';
}

/// Encodes entries for a single day, sorted by slot, as the compact JSON the
/// Kotlin provider decodes into RemoteViews rows.
///
/// Subgroup fold: collapse rows that share (slot, subject, teacher, classroom)
/// — these are the same lesson taught to two subgroups in parallel and should
/// read as one entry. Lab/practical splits where the teacher OR classroom
/// diverges stay as separate entries because they really are two distinct
/// lessons running at the same slot. Mirrors the rule applied to the week
/// widget in `widget_updater.dart` (1.2.6, commit 75a102c) — the today widget
/// had the same dup bug, fixed here in 1.2.7.
String encodeDayLessons(List<RaspisanieEntry> entries) {
  final sorted = [...entries]
    ..sort((a, b) => a.subjectNumber.compareTo(b.subjectNumber));
  final slotByOrdinal = {for (final s in lessonSlots) s.ordinal: s};
  final seenKeys = <String>{};
  final folded = <RaspisanieEntry>[];
  for (final e in sorted) {
    final foldKey =
        '${e.subjectNumber}|${e.subject.id}|${e.teacher.id}|${e.classroom}';
    if (!seenKeys.add(foldKey)) continue;
    folded.add(e);
  }
  return jsonEncode(folded.map((e) {
    final slot = slotByOrdinal[e.subjectNumber];
    return {
      'ordinal': e.subjectNumber,
      'start': slot?.start ?? '',
      'end': slot?.end ?? '',
      'subject': e.subject.name,
      'classroom': e.classroom,
      'teacher': e.teacher.name,
    };
  }).toList());
}

/// One subject entry on the week widget. `ord` is the lesson slot ordinal
/// (1-7) so the native side can render "1. Английский" with a bold prefix;
/// `name` is the subject display name.
class WeekSubject {
  final int ord;
  final String name;
  const WeekSubject({required this.ord, required this.name});
}

/// Row description for the week widget: one cube per weekday with the lesson
/// count (slot+subject-folded by the caller), a density bucket tag, an
/// `hasOverrides` flag used by the native side to pick the dot style
/// (gray/today-ring/yellow-fill) and the subject names with their slot
/// ordinals. The native side decides which names fit and truncates with "+N".
String encodeWeekSummary({
  required DateTime weekMonday,
  required Map<int, int> countsByWeekday,
  required Map<int, List<WeekSubject>> subjectsByWeekday,
  required Map<int, bool> hasOverridesByWeekday,
}) {
  const labels = <int, String>{
    1: 'Пн',
    2: 'Вт',
    3: 'Ср',
    4: 'Чт',
    5: 'Пт',
    6: 'Сб',
    7: 'Вс',
  };
  final rows = <Map<String, dynamic>>[];
  for (var w = 1; w <= 7; w++) {
    final date = weekMonday.add(Duration(days: w - 1));
    final subjects = subjectsByWeekday[w] ?? const <WeekSubject>[];
    rows.add({
      'weekday': w,
      'label': labels[w]!,
      'count': countsByWeekday[w] ?? 0,
      'date': _isoDate(date),
      'bucket': _densityBucket(countsByWeekday[w] ?? 0),
      'hasOverrides': hasOverridesByWeekday[w] ?? false,
      'subjects': subjects.map((s) => {'ord': s.ord, 'name': s.name}).toList(),
    });
  }
  return jsonEncode(rows);
}

/// Density bucket tag the native side uses to pick the dot drawable.
/// 0 → gray · 1-3 → green · 4-6 → yellow · 7+ → amber.
String _densityBucket(int count) {
  if (count <= 0) return 'empty';
  if (count <= 3) return 'low';
  if (count <= 6) return 'mid';
  return 'high';
}

String _isoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

enum CurrentLessonState { current, next, idle }

String currentLessonStateToString(CurrentLessonState s) => switch (s) {
      CurrentLessonState.current => 'current',
      CurrentLessonState.next => 'next',
      CurrentLessonState.idle => 'idle',
    };
