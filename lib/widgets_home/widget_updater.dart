import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../api/raspisanie_repository.dart';
import '../models/raspisanie.dart';
import '../state/auth.dart';
import '../state/schedule_filters.dart';
import '../state/settings.dart';
import '../theme/lesson_slots.dart';
import 'widget_data.dart';

const _androidPackage = 'ru.ncti.schedule.client.widgets';

bool _loopStarted = false;
Timer? _tick;
ProviderSubscription<AsyncValue<AuthState>>? _authSub;
ProviderSubscription<ScheduleFilters>? _filterSub;
ProviderSubscription<AsyncValue<ThemeMode>>? _themeSub;

/// Wires the refresh triggers that push schedule + theme data into the Android
/// home widgets: auth/filter/theme changes, a 15-minute tick, and a first
/// update shortly after boot. Safe to call more than once.
void startWidgetUpdateLoop(ProviderContainer container) {
  if (_loopStarted) return;
  if (kIsWeb) return;
  _loopStarted = true;

  Timer(const Duration(seconds: 3),
      () => unawaited(updateAllWidgets(container)));

  _tick?.cancel();
  _tick = Timer.periodic(const Duration(minutes: 15), (_) {
    unawaited(updateAllWidgets(container));
  });

  _authSub?.close();
  _authSub = container.listen<AsyncValue<AuthState>>(
    authProvider,
    (_, __) => unawaited(updateAllWidgets(container)),
  );
  _filterSub?.close();
  _filterSub = container.listen<ScheduleFilters>(
    scheduleFiltersProvider,
    (_, __) => unawaited(updateAllWidgets(container)),
  );
  _themeSub?.close();
  _themeSub = container.listen<AsyncValue<ThemeMode>>(
    themeModeProvider,
    (_, __) => unawaited(updateAllWidgets(container)),
  );
}

/// Reads filters + theme + the upcoming two weeks of raspisanie, packages the
/// result into shared prefs, and pokes each Android widget to redraw.
Future<void> updateAllWidgets(ProviderContainer container) async {
  if (kIsWeb) return;
  try {
    await _pushThemeKeys(container);

    final filters = container.read(scheduleFiltersProvider);
    final isCta = filters.isEmpty;
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.ctaMode, isCta);

    if (isCta) {
      // Nothing to fetch; blank the schedule payload so stale data doesn't
      // leak through when the provider decides to fall back out of CTA mode.
      await _clearScheduleKeys();
      await _pokeAll();
      return;
    }

    final repo = container.read(raspisanieRepositoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekMonday = today.subtract(Duration(days: now.weekday - 1));
    final summaryWeekMonday = weekSummaryAnchorMonday(today);
    // Fetch two weeks so the "next day with lessons" fallback has runway
    // past the current Sunday.
    final rangeEnd = weekMonday.add(const Duration(days: 13));

    List<RaspisanieEntry> rangeEntries = const <RaspisanieEntry>[];
    try {
      rangeEntries = await repo.fetch(
        groupIds: filters.groupId == null ? null : [filters.groupId!],
        teacherIds: filters.teacherId == null ? null : [filters.teacherId!],
        classrooms: filters.classroom == null ? null : [filters.classroom!],
        from: weekMonday,
        to: rangeEnd,
      );
    } catch (_) {
      // Offline / unauthed / anything else — render empty widgets.
    }

    // --- Today widget (with fallback to the next day that has lessons) ---
    final todayEntries = _entriesOn(rangeEntries, today);
    final todayRemaining = _remainingAfter(todayEntries, now);
    final selection = _selectDisplayDay(
      now: now,
      today: today,
      todayRemaining: todayRemaining,
      rangeEntries: rangeEntries,
      rangeEnd: rangeEnd,
    );

    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.todayLessons, encodeDayLessons(selection.entries));
    await HomeWidget.saveWidgetData<int>(
        WidgetKeys.todayCount, selection.entries.length);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.todayLabel, selection.label);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.todayDateIso, _isoDate(selection.date));
    await HomeWidget.saveWidgetData<bool>(
        WidgetKeys.todayIsFallback, selection.isFallback);

    // --- Week widget ---
    // Subgroup fold for the compact week widget: collapse rows that share a
    // lesson slot and subject. The widget only shows subject names, so two
    // subgroup variants with different rooms/teachers still read as a
    // duplicate there. The full schedule and today widget keep their richer
    // room/teacher-aware grouping.
    final weekRangeEnd = summaryWeekMonday.add(const Duration(days: 6));
    final seenKeys = <int, Set<String>>{};
    final subjectsPerWeekday = <int, List<WeekSubject>>{};
    final overridesPerWeekday = <int, bool>{};
    final inWeek = rangeEntries
        .where((e) =>
            !e.date.isBefore(summaryWeekMonday) &&
            !e.date.isAfter(weekRangeEnd))
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.subjectNumber.compareTo(b.subjectNumber);
      });
    for (final e in inWeek) {
      final wd = e.date.weekday;
      if (e.isOverride) overridesPerWeekday[wd] = true;
      final foldKey = weekSummaryFoldKey(e);
      final seen = seenKeys.putIfAbsent(wd, () => <String>{});
      if (!seen.add(foldKey)) continue;
      subjectsPerWeekday
          .putIfAbsent(wd, () => <WeekSubject>[])
          .add(WeekSubject(ord: e.subjectNumber, name: e.subject.name));
    }
    final counts = <int, int>{
      for (final entry in seenKeys.entries) entry.key: entry.value.length,
    };
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.weekSummary,
      encodeWeekSummary(
        weekMonday: summaryWeekMonday,
        countsByWeekday: counts,
        subjectsByWeekday: subjectsPerWeekday,
        hasOverridesByWeekday: overridesPerWeekday,
      ),
    );

    // --- Current-lesson widget ---
    final current = _currentOrNext(todayEntries, now);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.currentState,
        currentLessonStateToString(current.state));
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.currentSubject, current.subject);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.currentRoom, current.room);
    await HomeWidget.saveWidgetData<int>(
        WidgetKeys.currentMinsUntilOrLeft, current.minutes);
    // Epoch fields drive the Kotlin-side live minute counter.
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.currentEndEpochS, _epochSecsOrZero(current.endAt));
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.currentStartEpochS, _epochSecsOrZero(current.startAt));

    // Next + previous lookups for the tall modes. "Next" falls back to the
    // first lesson of the next non-empty day when there's nothing left today;
    // "afterNext" is the second upcoming slot on the same day as `next`
    // (empty when only one lesson remains). "Prev" stays day-local.
    final nextPair = _findNextPair(
      todayEntries: todayEntries,
      rangeEntries: rangeEntries,
      today: today,
      now: now,
      rangeEnd: rangeEnd,
    );
    final nextBlob = nextPair.next;
    final afterNextBlob = nextPair.afterNext;
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.nextSubject, nextBlob.subject);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.nextRoom, nextBlob.room);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.nextLabel, nextBlob.label);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.afterNextSubject, afterNextBlob.subject);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.afterNextRoom, afterNextBlob.room);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.afterNextLabel, afterNextBlob.label);

    final prevBlob = _findPrev(todayEntries, now);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.prevSubject, prevBlob.subject);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.prevRoom, prevBlob.room);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.prevLabel, prevBlob.label);

    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.updatedAt, now.toIso8601String());

    await _pokeAll();
  } catch (_) {
    // Home widget plumbing is best-effort.
  }
}

@visibleForTesting
String weekSummaryFoldKey(RaspisanieEntry e) =>
    '${e.subjectNumber}|${e.subject.id}';

@visibleForTesting
DateTime weekSummaryAnchorMonday(DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  if (day.weekday == DateTime.sunday) {
    return monday.add(const Duration(days: 7));
  }
  return monday;
}

Future<void> _pokeAll() async {
  await HomeWidget.updateWidget(
    name: 'TodayScheduleWidgetProvider',
    androidName: '$_androidPackage.TodayScheduleWidgetProvider',
  );
  await HomeWidget.updateWidget(
    name: 'CurrentLessonWidgetProvider',
    androidName: '$_androidPackage.CurrentLessonWidgetProvider',
  );
  await HomeWidget.updateWidget(
    name: 'WeekSummaryWidgetProvider',
    androidName: '$_androidPackage.WeekSummaryWidgetProvider',
  );
}

Future<void> _clearScheduleKeys() async {
  await HomeWidget.saveWidgetData<String>(WidgetKeys.todayLessons, '[]');
  await HomeWidget.saveWidgetData<int>(WidgetKeys.todayCount, 0);
  await HomeWidget.saveWidgetData<String>(WidgetKeys.todayLabel, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.todayDateIso, '');
  await HomeWidget.saveWidgetData<bool>(WidgetKeys.todayIsFallback, false);
  await HomeWidget.saveWidgetData<String>(WidgetKeys.weekSummary, '[]');
  await HomeWidget.saveWidgetData<String>(
      WidgetKeys.currentState, currentLessonStateToString(CurrentLessonState.idle));
  await HomeWidget.saveWidgetData<String>(WidgetKeys.currentSubject, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.currentRoom, '');
  await HomeWidget.saveWidgetData<int>(WidgetKeys.currentMinsUntilOrLeft, 0);
  await HomeWidget.saveWidgetData<String>(WidgetKeys.currentEndEpochS, '0');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.currentStartEpochS, '0');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.nextSubject, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.nextRoom, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.nextLabel, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.afterNextSubject, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.afterNextRoom, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.afterNextLabel, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.prevSubject, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.prevRoom, '');
  await HomeWidget.saveWidgetData<String>(WidgetKeys.prevLabel, '');
}

Future<void> _pushThemeKeys(ProviderContainer container) async {
  final user = container.read(currentUserProvider);
  final accent = user?.accentColor?.trim().isNotEmpty == true
      ? user!.accentColor!
      : defaultWidgetAccentHex;
  final mode =
      container.read(themeModeProvider).asData?.value ?? ThemeMode.system;
  final isDark = switch (mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => PlatformDispatcher.instance.platformBrightness ==
        Brightness.dark,
  };
  await HomeWidget.saveWidgetData<String>(WidgetKeys.themeAccent, accent);
  await HomeWidget.saveWidgetData<bool>(WidgetKeys.themeDark, isDark);
}

List<RaspisanieEntry> _entriesOn(
    List<RaspisanieEntry> all, DateTime day) {
  return all
      .where((e) =>
          e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day)
      .toList()
    ..sort((a, b) => a.subjectNumber.compareTo(b.subjectNumber));
}

List<RaspisanieEntry> _remainingAfter(
    List<RaspisanieEntry> sortedForDay, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final slotByOrdinal = {for (final s in lessonSlots) s.ordinal: s};
  final out = <RaspisanieEntry>[];
  for (final e in sortedForDay) {
    final slot = slotByOrdinal[e.subjectNumber];
    if (slot == null || !slot.hasTime) {
      out.add(e);
      continue;
    }
    final end = _parseTime(today, slot.end!);
    if (!now.isAfter(end)) out.add(e);
  }
  return out;
}

class _DaySelection {
  final DateTime date;
  final List<RaspisanieEntry> entries;
  final String label;
  final bool isFallback;
  const _DaySelection(
      this.date, this.entries, this.label, this.isFallback);
}

_DaySelection _selectDisplayDay({
  required DateTime now,
  required DateTime today,
  required List<RaspisanieEntry> todayRemaining,
  required List<RaspisanieEntry> rangeEntries,
  required DateTime rangeEnd,
}) {
  if (todayRemaining.isNotEmpty) {
    return _DaySelection(today, todayRemaining, _todayLabel(today), false);
  }
  // No more lessons today — scan forward up to rangeEnd.
  for (var i = 1; i <= rangeEnd.difference(today).inDays; i++) {
    final candidate = today.add(Duration(days: i));
    final entries = _entriesOn(rangeEntries, candidate);
    if (entries.isNotEmpty) {
      return _DaySelection(
        candidate,
        entries,
        _fallbackLabel(candidate),
        true,
      );
    }
  }
  return _DaySelection(today, const [], _todayLabel(today), false);
}

const _weekdayShort = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _monthShort = <String>[
  'янв', 'фев', 'мар', 'апр', 'май', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

String _todayLabel(DateTime d) {
  return 'Сегодня · ${d.day} ${_monthShort[d.month - 1]}';
}

String _fallbackLabel(DateTime d) {
  final wd = _weekdayShort[d.weekday - 1];
  return 'Следующий учебный день: $wd, ${d.day} ${_monthShort[d.month - 1]}';
}

String _isoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class _CurrentBlob {
  final CurrentLessonState state;
  final String subject;
  final String room;
  final int minutes;
  // Absolute moments the Kotlin side uses to recompute the countdown each
  // minute. null when there's no current/next slot to reference.
  final DateTime? startAt;
  final DateTime? endAt;
  const _CurrentBlob(
    this.state,
    this.subject,
    this.room,
    this.minutes, {
    this.startAt,
    this.endAt,
  });
}

String _epochSecsOrZero(DateTime? dt) =>
    (dt == null ? 0 : dt.millisecondsSinceEpoch ~/ 1000).toString();

_CurrentBlob _currentOrNext(
    List<RaspisanieEntry> todayEntries, DateTime now) {
  if (todayEntries.isEmpty) {
    return const _CurrentBlob(CurrentLessonState.idle, '', '', 0);
  }
  final today = DateTime(now.year, now.month, now.day);
  final slotByOrdinal = {for (final s in lessonSlots) s.ordinal: s};

  RaspisanieEntry? current;
  DateTime? currentEnd;
  RaspisanieEntry? next;
  DateTime? nextStart;

  for (final e in todayEntries) {
    final slot = slotByOrdinal[e.subjectNumber];
    if (slot == null || !slot.hasTime) continue;
    final start = _parseTime(today, slot.start!);
    final end = _parseTime(today, slot.end!);
    if (!now.isBefore(start) && now.isBefore(end)) {
      current = e;
      currentEnd = end;
      break;
    }
    if (now.isBefore(start) && next == null) {
      next = e;
      nextStart = start;
    }
  }

  if (current != null && currentEnd != null) {
    final mins = currentEnd.difference(now).inMinutes;
    return _CurrentBlob(
      CurrentLessonState.current,
      current.subject.name,
      current.classroom,
      mins.clamp(0, 600),
      endAt: currentEnd,
    );
  }
  if (next != null && nextStart != null) {
    final mins = nextStart.difference(now).inMinutes;
    return _CurrentBlob(
      CurrentLessonState.next,
      next.subject.name,
      next.classroom,
      mins.clamp(0, 60 * 24),
      startAt: nextStart,
    );
  }
  return const _CurrentBlob(CurrentLessonState.idle, '', '', 0);
}

class _Blob {
  final String subject;
  final String room;
  final String label;
  const _Blob(this.subject, this.room, this.label);
  static const empty = _Blob('', '', '');
}

class _NextPair {
  final _Blob next;
  final _Blob afterNext;
  const _NextPair(this.next, this.afterNext);
  static const empty = _NextPair(_Blob.empty, _Blob.empty);
}

/// Returns the lesson that comes *after* `now` on the same day, plus the
/// lesson after that one (when there's another slot left on the same day).
/// Falls back to the next non-empty day for `next` when the current day is
/// spent — in which case `afterNext` is the second lesson of that day, if
/// any. Labels distinguish "Далее"/"Завтра"/"Пн 13 мая" for `next` and
/// always "Затем" for `afterNext` (it's only meaningful as a runner-up).
_NextPair _findNextPair({
  required List<RaspisanieEntry> todayEntries,
  required List<RaspisanieEntry> rangeEntries,
  required DateTime today,
  required DateTime now,
  required DateTime rangeEnd,
}) {
  final slotByOrdinal = {for (final s in lessonSlots) s.ordinal: s};
  final upcomingToday = <RaspisanieEntry>[];
  for (final e in todayEntries) {
    final slot = slotByOrdinal[e.subjectNumber];
    if (slot == null || !slot.hasTime) continue;
    final start = _parseTime(today, slot.start!);
    if (now.isBefore(start)) upcomingToday.add(e);
  }
  if (upcomingToday.isNotEmpty) {
    final next = upcomingToday[0];
    final nextBlob = _Blob(next.subject.name, next.classroom, 'Далее');
    _Blob afterNextBlob = _Blob.empty;
    if (upcomingToday.length >= 2) {
      final after = upcomingToday[1];
      afterNextBlob = _Blob(after.subject.name, after.classroom, 'Затем');
    }
    return _NextPair(nextBlob, afterNextBlob);
  }
  // Nothing left today — scan forward.
  for (var i = 1; i <= rangeEnd.difference(today).inDays; i++) {
    final candidate = today.add(Duration(days: i));
    final entries = _entriesOn(rangeEntries, candidate);
    if (entries.isEmpty) continue;
    final first = entries.first;
    final label = i == 1
        ? 'Завтра'
        : '${_weekdayShort[candidate.weekday - 1]} ${candidate.day} ${_monthShort[candidate.month - 1]}';
    final nextBlob = _Blob(first.subject.name, first.classroom, label);
    _Blob afterNextBlob = _Blob.empty;
    if (entries.length >= 2) {
      final after = entries[1];
      afterNextBlob = _Blob(after.subject.name, after.classroom, 'Затем');
    }
    return _NextPair(nextBlob, afterNextBlob);
  }
  return _NextPair.empty;
}

_Blob _findPrev(List<RaspisanieEntry> todayEntries, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final slotByOrdinal = {for (final s in lessonSlots) s.ordinal: s};
  RaspisanieEntry? last;
  for (final e in todayEntries) {
    final slot = slotByOrdinal[e.subjectNumber];
    if (slot == null || !slot.hasTime) continue;
    final end = _parseTime(today, slot.end!);
    if (!now.isBefore(end)) {
      // Ended on or before now → candidate for "previous".
      last = e;
    }
  }
  if (last == null) return _Blob.empty;
  return _Blob(last.subject.name, last.classroom, 'Ранее');
}

DateTime _parseTime(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}
