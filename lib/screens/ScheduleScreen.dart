import 'dart:ui' as ui;

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../api/note_storage.dart';
import '../api/raspisanie_repository.dart';
import '../common/accent_color.dart';
import '../common/cold_launch_timing.dart';
import '../common/palette_region.dart';
import '../common/time_format.dart';
import '../common/top_banner.dart';
import '../common/week_list_format.dart';
import '../common/week_math.dart' as week_math;
import '../l10n/generated/app_localizations.dart';
import '../models/app_user.dart';
import '../models/pinned_day_note.dart';
import '../models/queued_note_op.dart';
import '../models/raspisanie.dart';
import '../state/auth.dart';
import '../state/connectivity.dart';
import '../state/debug_clock.dart';
import '../state/note_queue.dart';
import '../state/notifications.dart';
import '../state/schedule_filters.dart';
import '../state/settings.dart';
import '../theme/app_palette.dart';
import '../theme/lesson_slots.dart';

String _weekdayShort(AppLocalizations l10n, int mondayZeroBased) {
  return switch (mondayZeroBased) {
    0 => l10n.weekdayShortMon,
    1 => l10n.weekdayShortTue,
    2 => l10n.weekdayShortWed,
    3 => l10n.weekdayShortThu,
    4 => l10n.weekdayShortFri,
    5 => l10n.weekdayShortSat,
    _ => l10n.weekdayShortSun,
  };
}

String _weekdayLong(AppLocalizations l10n, int isoWeekday) {
  return switch (isoWeekday) {
    1 => l10n.weekdayLongMon,
    2 => l10n.weekdayLongTue,
    3 => l10n.weekdayLongWed,
    4 => l10n.weekdayLongThu,
    5 => l10n.weekdayLongFri,
    6 => l10n.weekdayLongSat,
    _ => l10n.weekdayLongSun,
  };
}

String _monthLong(AppLocalizations l10n, int month) {
  return switch (month) {
    1 => l10n.monthLongJan,
    2 => l10n.monthLongFeb,
    3 => l10n.monthLongMar,
    4 => l10n.monthLongApr,
    5 => l10n.monthLongMay,
    6 => l10n.monthLongJun,
    7 => l10n.monthLongJul,
    8 => l10n.monthLongAug,
    9 => l10n.monthLongSep,
    10 => l10n.monthLongOct,
    11 => l10n.monthLongNov,
    _ => l10n.monthLongDec,
  };
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

String _monthShort(AppLocalizations l10n, int month) {
  return switch (month) {
    1 => l10n.monthShortJan,
    2 => l10n.monthShortFeb,
    3 => l10n.monthShortMar,
    4 => l10n.monthShortApr,
    5 => l10n.monthShortMay,
    6 => l10n.monthShortJun,
    7 => l10n.monthShortJul,
    8 => l10n.monthShortAug,
    9 => l10n.monthShortSep,
    10 => l10n.monthShortOct,
    11 => l10n.monthShortNov,
    _ => l10n.monthShortDec,
  };
}

const _lessonListMaxWidth = 700.0;
const _monthGridMaxWidth = 520.0; // ≈64px cells (520/7=74, minus padding)

/// One-shot guard so the first-data-arrival timing log fires once per app
/// process, NOT on every rebuild after the schedule provider settles.
bool _scheduleFirstDataLogged = false;

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(monthRaspisanieProvider);
    final cached = ref.watch(lastMonthEntriesProvider);

    final data = async.asData?.value ?? cached ?? const <RaspisanieEntry>[];
    if (!_scheduleFirstDataLogged && async.asData != null) {
      _scheduleFirstDataLogged = true;
      logTiming('schedule.first_data_arrival');
    }
    final showTopLoader = async.isLoading && cached != null;
    final showFullLoader = async.isLoading && cached == null;
    final hasError = async.hasError && cached == null;
    final selected = ref.watch(selectedDateProvider);
    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    final selectedAtMidnight =
        DateTime(selected.year, selected.month, selected.day);
    final daysFromToday =
        selectedAtMidnight.difference(todayAtMidnight).inDays.abs();
    final viewMode = ref.watch(scheduleViewModeProvider).asData?.value ??
        ScheduleViewMode.grid;
    // Week-list view shifts the FAB threshold from "≥2 days off" to "off the
    // current week" so the user can snap back from any non-current week
    // even when selection lands on a Sunday/Monday adjacent to today.
    final showReturnToToday = viewMode == ScheduleViewMode.weekList
        ? !_sameWeek(selectedAtMidnight, todayAtMidnight)
        : daysFromToday >= 2;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(
          l10n.scheduleTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: showTopLoader
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      floatingActionButton: showReturnToToday
          ? FloatingActionButton.extended(
              onPressed: () {
                final now = DateTime.now();
                final t = DateTime(now.year, now.month, now.day);
                ref.read(selectedDateProvider.notifier).set(t);
                ref
                    .read(displayedMonthProvider.notifier)
                    .set(DateTime(t.year, t.month, 1));
                ref
                    .read(stripVisibleMonthProvider.notifier)
                    .set(DateTime(t.year, t.month, 1));
                // 1.3.7 Item 3: in week-list view, also scroll the body
                // vertically so today's day section is in view. The pulse
                // is harmless in grid/day-strip — only WeekListScheduleBody
                // listens.
                ref.read(returnToTodayPulseProvider.notifier).pulse();
              },
              icon: const Icon(Icons.today),
              label: Text(l10n.scheduleReturnToToday),
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              const _OfflineBanner(),
              Expanded(
                child: hasError
                    ? _ErrorView(
                        message: _prettyScheduleError(l10n, async.error),
                        onRetry: () {
                          final month = ref.read(displayedMonthProvider);
                          final filters = ref.read(scheduleFiltersProvider);
                          ref.invalidate(monthRaspisanieByMonthProvider(
                              monthFilterParamsFor(month, filters)));
                        },
                      )
                    : showFullLoader
                        ? const Center(child: CircularProgressIndicator())
                        : ScheduleBodyView(entries: data),
              ),
            ],
          ),
          const Positioned(
            right: 12,
            bottom: 12,
            child: _DebugClockPill(),
          ),
        ],
      ),
    );
  }
}

/// Public re-entry point: renders the month/day layout without the
/// AppBar/offline-banner wrapper. The embed route uses this to fit the
/// schedule inside an iframe.
class ScheduleBodyView extends ConsumerWidget {
  const ScheduleBodyView({
    super.key,
    required this.entries,
    this.embed = false,
    this.filterTrailing,
  });
  final List<RaspisanieEntry> entries;
  final bool embed;
  final Widget? filterTrailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ScheduleBody(
      entries: entries,
      embed: embed,
      filterTrailing: filterTrailing,
    );
  }
}

/// Retains the last-successfully-rendered entries across filter/month
/// changes so the UI can show stale data while a new fetch is in flight.
/// Stores state on the notifier instance so it survives rebuilds triggered
/// by a watched provider flipping to AsyncLoading.
class _LastMonthEntriesNotifier extends Notifier<List<RaspisanieEntry>?> {
  List<RaspisanieEntry>? _prev;

  @override
  List<RaspisanieEntry>? build() {
    ref.keepAlive();
    final filters = ref.watch(scheduleFiltersProvider);
    final value = ref.watch(monthRaspisanieProvider).asData?.value;
    // Only cache real fetches; the empty list returned when no filter is
    // active would otherwise mask the full-screen spinner for the very
    // first fetch after a filter is set.
    if (value != null && !filters.isEmpty) _prev = value;
    return _prev;
  }
}

final lastMonthEntriesProvider =
    NotifierProvider<_LastMonthEntriesNotifier, List<RaspisanieEntry>?>(
        _LastMonthEntriesNotifier.new);

class _ScheduleBody extends ConsumerWidget {
  const _ScheduleBody({
    required this.entries,
    this.embed = false,
    this.filterTrailing,
  });
  final List<RaspisanieEntry> entries;
  final bool embed;
  final Widget? filterTrailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayedMonth = ref.watch(displayedMonthProvider);
    final selected = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(scheduleViewModeProvider).asData?.value ??
        ScheduleViewMode.grid;
    // Grid is the only mode that benefits from adjacent-month warming. Day
    // strip already watches its bounded strip window, and week-list watches
    // only the month(s) touched by the selected week; running the generic
    // preloader there adds network/cache work without changing the first
    // visible frame.
    if (viewMode == ScheduleViewMode.grid) {
      ref.watch(adjacentMonthPreloadProvider);
    }
    if (viewMode == ScheduleViewMode.weekList) {
      return WeekListScheduleBody(embed: embed, filterTrailing: filterTrailing);
    }
    final showCarousel = viewMode == ScheduleViewMode.dayStrip;
    final today = _dateOnly(ref.watch(nowProvider));

    // Source-of-truth entries for cell coloring + the schedule body. Grid
    // mode uses the displayed-month entries from the parent (1.2.13). Day-
    // strip mode fans out ±stripWindowRadius months so days outside the
    // centre month colour correctly and tapping any visible cell shows real
    // schedule data without waiting for displayedMonthProvider to refetch.
    final List<RaspisanieEntry> sourceEntries;
    final Set<DateTime> notedDates;
    final Map<DateTime, List<Color>> notifColorsByDate;
    final Set<DateTime> loadedStripMonths;
    if (showCarousel) {
      final months = ref.watch(stripWindowMonthsProvider);
      final filters = ref.watch(scheduleFiltersProvider);
      final all = <RaspisanieEntry>[];
      final notes = <DateTime>{};
      final pinned = <DateTime, List<Color>>{};
      final loaded = <DateTime>{};
      for (final m in months) {
        final raspAsync = ref.watch(
            monthRaspisanieByMonthProvider(monthFilterParamsFor(m, filters)));
        final notesAsync = ref.watch(monthNotesByMonthProvider(m));
        final pinnedAsync = ref.watch(pinnedNotesForMonthProvider(m));
        final raspData = raspAsync.asData?.value;
        if (raspData != null) {
          all.addAll(raspData);
          loaded.add(DateTime(m.year, m.month, 1));
        }
        final notesData = notesAsync.asData?.value;
        if (notesData != null) notes.addAll(notesData);
        final pinnedData = pinnedAsync.asData?.value;
        if (pinnedData != null) {
          pinnedData.forEach((k, v) {
            pinned.putIfAbsent(k, () => <Color>[]).addAll(v);
          });
        }
      }
      // ±stripWindowRadius month providers' grid windows overlap (each one
      // is gridStartFor..gridEndFor → 42 days, often spilling into the
      // adjacent month), so the same row appears twice if we take `all` raw.
      // Dedup here, before dayIndex is built, so all consumers see one entry
      // per (date, slot, subgroup, …) tuple.
      sourceEntries = dedupRaspisanieEntries(all);
      notedDates = notes;
      notifColorsByDate = pinned;
      loadedStripMonths = loaded;
    } else {
      sourceEntries = entries;
      notedDates =
          ref.watch(monthNotesProvider).asData?.value ?? const <DateTime>{};
      notifColorsByDate =
          ref.watch(displayedMonthPinnedProvider).asData?.value ??
              const <DateTime, List<Color>>{};
      loadedStripMonths = const <DateTime>{};
    }

    final dayIndex = <DateTime, List<RaspisanieEntry>>{};
    final overrideDates = <DateTime>{};
    for (final e in sourceEntries) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      dayIndex.putIfAbsent(key, () => []).add(e);
      if (e.isOverride) overrideDates.add(key);
    }
    final lessonsByDate = dayIndex.keys.toSet();
    final shablonPattern = shablonPatternFromEntries(sourceEntries);

    // In carousel mode the month label follows strip-scroll (a UI-only cue)
    // while the grid uses the data-fetch month. Selection highlight is
    // driven by `selected` in both modes — neither label source touches it.
    final month =
        showCarousel ? ref.watch(stripVisibleMonthProvider) : displayedMonth;

    final selectedEntries =
        dayIndex[_dateOnly(selected)] ?? const <RaspisanieEntry>[];

    Widget calendarBlock() {
      if (showCarousel) {
        return _WeekStripCalendar(
          selected: selected,
          today: today,
          lessonsByDate: lessonsByDate,
          overrideDates: overrideDates,
          notedDates: notedDates,
          notifColorsByDate: notifColorsByDate,
          loadedMonths: loadedStripMonths,
          shablonPattern: shablonPattern,
        );
      }
      return _MonthGrid(
        month: month,
        shablonPattern: shablonPattern,
        notedDates: notedDates,
        notifColorsByDate: notifColorsByDate,
        lessonsByDate: lessonsByDate,
        overrideDates: overrideDates,
      );
    }

    final viewportWidth = MediaQuery.of(context).size.width;
    // Day-strip + desktop viewport: full-width strip on top, then a Row
    // [schedule body, day-notes column]. Below 1100 strip mode falls back
    // to the mobile vertical stack (the lesson list and notes already self-
    // centre via _lessonListMaxWidth, so tablet widths look fine stacked).
    final isDesktopStrip = showCarousel && viewportWidth >= 1100 && !embed;
    final isWideSplit =
        !isDesktopStrip && !showCarousel && viewportWidth >= 900;

    if (isDesktopStrip) {
      return _DesktopStripLayout(
        filterTrailing: filterTrailing,
        month: month,
        calendarBlock: calendarBlock,
        selectedDate: selected,
        selectedEntries: selectedEntries,
      );
    }

    if (isWideSplit) {
      final divider = VerticalDivider(
        width: 1,
        thickness: 1,
        color: AppPalette.of(context).subtleDivider,
      );
      if (embed) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DayLessons(date: selected, entries: selectedEntries),
                    _DayNoteSection(date: selected),
                    _PinnedNotesSection(date: selected),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              divider,
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterBar(trailing: filterTrailing),
                    _MonthHeader(month: month),
                    calendarBlock(),
                    _LegendRow(shablonPattern: shablonPattern),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: CustomScrollView(
              slivers: [
                _DayLessonsSlivers(date: selected, entries: selectedEntries),
                SliverToBoxAdapter(child: _DayNoteSection(date: selected)),
                SliverToBoxAdapter(child: _PinnedNotesSection(date: selected)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
          divider,
          Expanded(
            flex: 4,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _FilterBar()),
                SliverToBoxAdapter(child: _MonthHeader(month: month)),
                SliverToBoxAdapter(child: calendarBlock()),
                SliverToBoxAdapter(
                    child: _LegendRow(shablonPattern: shablonPattern)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ],
      );
    }

    if (embed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterBar(trailing: filterTrailing),
          _MonthHeader(month: month),
          calendarBlock(),
          if (!showCarousel) _LegendRow(shablonPattern: shablonPattern),
          _DayLessons(date: selected, entries: selectedEntries),
          _DayNoteSection(date: selected),
          _PinnedNotesSection(date: selected),
          const SizedBox(height: 24),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _FilterBar(trailing: filterTrailing)),
        SliverToBoxAdapter(child: _MonthHeader(month: month)),
        SliverToBoxAdapter(child: calendarBlock()),
        if (!showCarousel)
          SliverToBoxAdapter(child: _LegendRow(shablonPattern: shablonPattern)),
        _DayLessonsSlivers(date: selected, entries: selectedEntries),
        SliverToBoxAdapter(child: _DayNoteSection(date: selected)),
        SliverToBoxAdapter(child: _PinnedNotesSection(date: selected)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// PC layout for the day-strip mode. Filter bar / month header / strip span
/// the full viewport width up top; below them sits a centred Row with the
/// schedule body on the left (max [_lessonListMaxWidth]) and day-notes +
/// pinned-notes stacked in a fixed-width column on the right. Each side
/// scrolls independently so a long lesson list can scroll past static notes.
class _DesktopStripLayout extends StatelessWidget {
  const _DesktopStripLayout({
    required this.filterTrailing,
    required this.month,
    required this.calendarBlock,
    required this.selectedDate,
    required this.selectedEntries,
  });

  final Widget? filterTrailing;
  final DateTime month;
  final Widget Function() calendarBlock;
  final DateTime selectedDate;
  final List<RaspisanieEntry> selectedEntries;

  static const double _notesColumnWidth = 320.0;
  static const double _columnGap = 16.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(trailing: filterTrailing),
        _MonthHeader(month: month),
        calendarBlock(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _lessonListMaxWidth),
                child: CustomScrollView(
                  slivers: [
                    _DayLessonsSlivers(
                        date: selectedDate, entries: selectedEntries),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
              const SizedBox(width: _columnGap),
              SizedBox(
                width: _notesColumnWidth,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DayNoteSection(date: selectedDate),
                      _PinnedNotesSection(date: selectedDate),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({this.trailing});
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filters = ref.watch(scheduleFiltersProvider);
    final groupsAsync = ref.watch(allGroupsProvider);
    final teachersAsync = ref.watch(allTeachersProvider);
    final classroomsAsync = ref.watch(allClassroomsProvider);

    String? groupLabel;
    if (filters.groupId != null) {
      groupLabel = groupsAsync.maybeWhen(
        data: (g) => g
            .firstWhere(
              (e) => e.id == filters.groupId,
              orElse: () => const NamedRef(id: 0, name: '?'),
            )
            .name,
        orElse: () => '...',
      );
    }
    String? teacherLabel;
    if (filters.teacherId != null) {
      teacherLabel = teachersAsync.maybeWhen(
        data: (g) => g
            .firstWhere(
              (e) => e.id == filters.teacherId,
              orElse: () => const NamedRef(id: 0, name: '?'),
            )
            .name,
        orElse: () => '...',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FilterChipButton(
            label: l10n.scheduleFilterGroup,
            value: groupLabel,
            onTap: () => _pickNamed(
              context,
              ref,
              title: l10n.scheduleFilterGroupPick,
              async: groupsAsync,
              selected: filters.groupId,
              onSelect: (id) =>
                  ref.read(scheduleFiltersProvider.notifier).setGroup(id),
            ),
            onClear: filters.groupId == null
                ? null
                : () =>
                    ref.read(scheduleFiltersProvider.notifier).setGroup(null),
          ),
          _FilterChipButton(
            label: l10n.scheduleFilterTeacher,
            value: teacherLabel,
            onTap: () => _pickNamed(
              context,
              ref,
              title: l10n.scheduleFilterTeacherPick,
              async: teachersAsync,
              selected: filters.teacherId,
              onSelect: (id) =>
                  ref.read(scheduleFiltersProvider.notifier).setTeacher(id),
            ),
            onClear: filters.teacherId == null
                ? null
                : () =>
                    ref.read(scheduleFiltersProvider.notifier).setTeacher(null),
          ),
          _FilterChipButton(
            label: l10n.scheduleFilterRoom,
            value: filters.classroom,
            onTap: () => _pickClassroom(
              context,
              ref,
              async: classroomsAsync,
              selected: filters.classroom,
              onSelect: (v) =>
                  ref.read(scheduleFiltersProvider.notifier).setClassroom(v),
            ),
            onClear: filters.classroom == null
                ? null
                : () => ref
                    .read(scheduleFiltersProvider.notifier)
                    .setClassroom(null),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Future<void> _pickNamed(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required AsyncValue<List<NamedRef>> async,
    required int? selected,
    required void Function(int?) onSelect,
  }) async {
    final items = async.asData?.value ?? const <NamedRef>[];
    final pick = await showDialog<_PickResult<int>>(
      context: context,
      builder: (_) => _PickDialog<int>(
        title: title,
        options:
            items.map((e) => _PickOption(id: e.id, label: e.name)).toList(),
        selected: selected,
      ),
    );
    if (pick != null) onSelect(pick.value);
  }

  Future<void> _pickClassroom(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<String>> async,
    required String? selected,
    required void Function(String?) onSelect,
  }) async {
    final items = async.asData?.value ?? const <String>[];
    final pick = await showDialog<_PickResult<String>>(
      context: context,
      builder: (_) => _PickDialog<String>(
        title: AppLocalizations.of(context).scheduleFilterRoomPick,
        options: items.map((e) => _PickOption(id: e, label: e)).toList(),
        selected: selected,
      ),
    );
    if (pick != null) onSelect(pick.value);
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    final c = AppPalette.of(context);
    final accent = c.scheduleSelected;
    final onAccent = c.scheduleSelectedText;
    final inactiveFill = c.lessonCardFill;
    final inactiveBorder = c.lessonCardBorder;
    final inactiveText = c.lessonCardTitle;
    return Material(
      color: active ? accent : inactiveFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: active ? accent : inactiveBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                active ? '$label: ${value!}' : label,
                style: TextStyle(
                  color: active ? onAccent : inactiveText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 16, color: onAccent),
                ),
              ] else ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    size: 18, color: c.lessonCardSubtitle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickOption<T> {
  final T id;
  final String label;
  const _PickOption({required this.id, required this.label});
}

class _PickResult<T> {
  final T? value;
  const _PickResult(this.value);
}

class _PickDialog<T> extends StatefulWidget {
  const _PickDialog({
    required this.title,
    required this.options,
    required this.selected,
  });
  final String title;
  final List<_PickOption<T>> options;
  final T? selected;

  @override
  State<_PickDialog<T>> createState() => _PickDialogState<T>();
}

class _PickDialogState<T> extends State<_PickDialog<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) =>
            _query.isEmpty ||
            o.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.commonSearch,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final o = filtered[i];
                  final selected = widget.selected == o.id;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    title: Text(o.label),
                    trailing: selected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () =>
                        Navigator.of(context).pop(_PickResult<T>(o.id)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const _PickResult<Never>(null)),
          child: Text(l10n.commonReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

class _MonthHeader extends ConsumerWidget {
  const _MonthHeader({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final prev = DateTime(month.year, month.month - 1, 1);
              ref.read(displayedMonthProvider.notifier).set(prev);
              ref.read(stripVisibleMonthProvider.notifier).set(prev);
            },
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).scheduleMonthHeader(
              _monthLong(AppLocalizations.of(context), month.month),
              month.year,
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppPalette.of(context).dayHeadingText,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final next = DateTime(month.year, month.month + 1, 1);
              ref.read(displayedMonthProvider.notifier).set(next);
              ref.read(stripVisibleMonthProvider.notifier).set(next);
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    required this.month,
    required this.shablonPattern,
    required this.notedDates,
    required this.notifColorsByDate,
    required this.lessonsByDate,
    required this.overrideDates,
  });
  final DateTime month;
  // Shablon is still consulted for *mode selection* (`auto` picks evenOdd
  // when the shablon has a parity split) and to render the legend, but the
  // has-lessons decision per cell now reads from the effective raspisanie
  // so override-only additions paint as filled and cancellation overrides
  // paint as empty.
  final ShablonWeekdayPattern shablonPattern;
  final Set<DateTime> notedDates;
  final Map<DateTime, List<Color>> notifColorsByDate;
  final Set<DateTime> lessonsByDate;
  final Set<DateTime> overrideDates;

  static const _rows = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final today = _dateOnly(ref.watch(nowProvider));

    final firstOfMonth = DateTime(month.year, month.month, 1);
    final lead = (firstOfMonth.weekday - 1); // Monday=0..Sunday=6
    final gridStart = firstOfMonth.subtract(Duration(days: lead));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _monthGridMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  for (int i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          _weekdayShort(AppLocalizations.of(context), i),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppPalette.of(context).weekHeaderText,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (int r = 0; r < _rows; r++)
                Row(
                  children: [
                    for (int c = 0; c < 7; c++)
                      Expanded(
                        child: _buildCell(
                          context,
                          ref,
                          gridStart.add(Duration(days: r * 7 + c)),
                          selected,
                          today,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    DateTime selected,
    DateTime today,
  ) {
    final c = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inMonth = date.month == month.month;
    final isToday = _sameDay(date, today);
    final isSelected = _sameDay(date, selected);
    final hasNote = notedDates.contains(_dateOnly(date));
    final notifColors = notifColorsByDate[_dateOnly(date)] ?? const <Color>[];
    final hasNotif = notifColors.isNotEmpty;
    final even = _isEvenWeek(date);
    final rawMode = ref.watch(dayColoringModeProvider).asData?.value ??
        DayColoringMode.auto;
    final mode = rawMode == DayColoringMode.auto
        ? (shablonPattern.hasEvenOddSplit
            ? DayColoringMode.evenOdd
            : DayColoringMode.hasLessons)
        : rawMode;

    final dateKey = _dateOnly(date);
    final hasLessonsEffective = lessonsByDate.contains(dateKey);
    final hasOverride = overrideDates.contains(dateKey);

    Color fill;
    String fillToken;
    if (mode == DayColoringMode.evenOdd) {
      if (hasLessonsEffective) {
        fill = even ? c.scheduleEvenWeek : c.scheduleOddWeek;
        fillToken = even
            ? PaletteTokens.scheduleEvenWeek
            : PaletteTokens.scheduleOddWeek;
      } else {
        fill = c.scheduleNoLessonsInMonth;
        fillToken = PaletteTokens.scheduleNoLessonsInMonth;
      }
    } else {
      if (hasLessonsEffective) {
        fill = c.scheduleHasLessons;
        fillToken = PaletteTokens.scheduleHasLessons;
      } else {
        fill = c.scheduleNoLessonsInMonth;
        fillToken = PaletteTokens.scheduleNoLessonsInMonth;
      }
    }
    if (isSelected) {
      fill = c.scheduleSelected;
      fillToken = PaletteTokens.scheduleSelected;
    }

    Color textColor;
    if (isSelected) {
      textColor = c.scheduleSelectedText;
    } else if (!inMonth) {
      textColor = c.scheduleOutMonthText;
    } else if (isToday) {
      textColor = c.scheduleSelected;
    } else {
      textColor = c.scheduleInMonthText;
    }

    Border? border;
    if (isToday) {
      border = Border.all(color: c.scheduleTodayRing, width: 1.5);
    } else if (hasNote) {
      border = Border.all(color: _noteOutline(fill, isDark), width: 2);
    }

    final select =
        () => ref.read(selectedDateProvider.notifier).set(_dateOnly(date));
    final openNote = () {
      select();
      _openNoteDialog(context, ref, _dateOnly(date));
    };

    const radius = 8.0;

    final inner = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight:
                      isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),
          ),
          if (hasOverride)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.scheduleOverride,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    final cellBody = hasNotif
        ? _AccentOutlineWrap(
            colors: notifColors,
            radius: radius,
            child: inner,
          )
        : inner;

    final wrapped = cellBody;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: PaletteRegion(
          token: fillToken,
          child: GestureDetector(
            onSecondaryTapUp: (_) => openNote(),
            onLongPress: openNote,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius + (hasNotif ? 2 : 0)),
              onTap: select,
              child: wrapped,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal day-strip alternative to the 6-row month grid. Renders
/// ±_kStripRange days around today and lets the user flick through them;
/// the initial scroll lands on [selected] so the picker opens on the
/// currently-selected date. Tapping a cell updates
/// `selectedDateProvider` and `displayedMonthProvider` so month-scoped
/// data loads keep pace with the visible window.
///
/// The strip is intentionally "linear-infinite" rather than a true
/// paginator: epoch-day math makes cross-month math seamless without
/// per-month bookkeeping, and the fixed 801-day range (±400 days) is
/// large enough to cover a full academic year in either direction before
/// the user would sensibly jump via the month header instead.
class _WeekStripCalendar extends ConsumerStatefulWidget {
  const _WeekStripCalendar({
    required this.selected,
    required this.today,
    required this.lessonsByDate,
    required this.overrideDates,
    required this.notedDates,
    required this.notifColorsByDate,
    required this.loadedMonths,
    required this.shablonPattern,
  });

  final DateTime selected;
  final DateTime today;
  final Set<DateTime> lessonsByDate;
  final Set<DateTime> overrideDates;
  final Set<DateTime> notedDates;
  final Map<DateTime, List<Color>> notifColorsByDate;

  /// First-of-month DateTimes whose raspisanie has loaded at least once.
  /// Cells in months outside this set render as a neutral surface (data not
  /// fetched yet) instead of "no lessons" so an in-flight scroll past the
  /// strip's current window doesn't paint hundreds of fake-empty days.
  final Set<DateTime> loadedMonths;

  /// Drives the auto resolution between hasLessons and evenOdd colouring.
  final ShablonWeekdayPattern shablonPattern;

  @override
  ConsumerState<_WeekStripCalendar> createState() => _WeekStripCalendarState();
}

class _WeekStripCalendarState extends ConsumerState<_WeekStripCalendar> {
  static const _cellWidth = 56.0;
  static const _cellHeight = 68.0;
  static const _range = 400;
  // Mirrors the ListView's `padding: EdgeInsets.symmetric(horizontal: 8)` —
  // the first item sits 8 px past scrollOffset 0, so all centre-math has to
  // account for it.
  static const _leadingPad = 8.0;
  late final ScrollController _controller;
  DateTime? _lastCentered;
  int? _lastReportedMonthIndex;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_onScroll);
    _lastCentered = _dateOnly(widget.selected);
    // Viewport width isn't known until first layout, so defer the initial
    // centring jump to the first post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_centerOffsetFor(widget.selected));
      // Seed the strip's visible-month to the selected date's month so the
      // month header above the carousel matches the initial scroll position.
      final sel = _dateOnly(widget.selected);
      final seed = DateTime(sel.year, sel.month, 1);
      final cur = ref.read(stripVisibleMonthProvider);
      if (cur.year != seed.year || cur.month != seed.month) {
        ref.read(stripVisibleMonthProvider.notifier).set(seed);
      }
      _lastReportedMonthIndex = seed.year * 12 + (seed.month - 1);
    });
  }

  @override
  void didUpdateWidget(_WeekStripCalendar old) {
    super.didUpdateWidget(old);
    // Re-center when the selection moves via the external notifier (e.g.
    // from a widget deep-link or a tap on a cell) so the strip tracks the
    // source of truth.
    final sel = _dateOnly(widget.selected);
    if (_lastCentered == null || !_sameDay(_lastCentered!, sel)) {
      _lastCentered = sel;
      if (_controller.hasClients) {
        _controller.animateTo(
          _centerOffsetFor(sel),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() => _maybeReportMonth();

  /// Update [stripVisibleMonthProvider] to match the month of the date
  /// currently at the viewport's horizontal centre. Cheap-no-op when the
  /// centre date stays in the same month across scroll frames.
  ///
  /// Intentionally *does not* touch [displayedMonthProvider] — that drives
  /// data fetches (raspisanie / notes / notifications) and scroll shouldn't
  /// force a refetch. Keeping the two separate also severs a parent-rebuild
  /// path that was causing the selected-day highlight to appear to jump on
  /// scroll.
  void _maybeReportMonth() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final viewport = pos.viewportDimension;
    if (viewport <= 0) return;
    final centerPx = pos.pixels + viewport / 2;
    final index =
        ((centerPx - _leadingPad - _cellWidth / 2) / _cellWidth).round();
    final clamped = index.clamp(0, _range * 2);
    final date = _dateAtIndex(clamped);
    final monthIndex = date.year * 12 + (date.month - 1);
    if (_lastReportedMonthIndex == monthIndex) return;
    _lastReportedMonthIndex = monthIndex;
    final newMonth = DateTime(date.year, date.month, 1);
    final cur = ref.read(stripVisibleMonthProvider);
    if (cur.year != newMonth.year || cur.month != newMonth.month) {
      ref.read(stripVisibleMonthProvider.notifier).set(newMonth);
    }
  }

  /// Scroll offset such that [date] sits at the horizontal *centre* of the
  /// viewport, accounting for the ListView's leading padding. Falls back to
  /// the raw item-start offset if the controller has no viewport yet.
  double _centerOffsetFor(DateTime date) {
    final todayEpoch = _epochDays(widget.today);
    final index = (_epochDays(date) - todayEpoch) + _range;
    final itemCenter = _leadingPad + index * _cellWidth + _cellWidth / 2;
    if (!_controller.hasClients) return itemCenter - _cellWidth / 2;
    final pos = _controller.position;
    final viewport = pos.viewportDimension;
    final raw = itemCenter - viewport / 2;
    return raw.clamp(pos.minScrollExtent, pos.maxScrollExtent);
  }

  int _epochDays(DateTime d) {
    final utc = DateTime.utc(d.year, d.month, d.day);
    return utc.millisecondsSinceEpoch ~/ (24 * 3600 * 1000);
  }

  DateTime _dateAtIndex(int index) {
    final delta = index - _range;
    return _dateOnly(widget.today).add(Duration(days: delta));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final rawMode = ref.watch(dayColoringModeProvider).asData?.value ??
        DayColoringMode.auto;
    final mode = rawMode == DayColoringMode.auto
        ? (widget.shablonPattern.hasEvenOddSplit
            ? DayColoringMode.evenOdd
            : DayColoringMode.hasLessons)
        : rawMode;
    // 1.3.4 Item 1: long-press a day cell to open the note dialog. Mirrors
    // the grid's existing long-press affordance so the day-strip view has
    // parity. Guests have no note-edit flow, so the gesture is suppressed
    // for them (regular tap-to-select still works).
    final canAuthorNote = ref.watch(currentUserProvider) != null;
    return SizedBox(
      height: _cellHeight + 8,
      child: Listener(
        onPointerSignal: (signal) {
          // Translate vertical mouse-wheel ticks into horizontal strip
          // scroll on desktop/web. Without this the wheel does nothing
          // useful over a horizontal list (the page scrolls vertically
          // underneath instead).
          if (signal is PointerScrollEvent &&
              _controller.hasClients &&
              signal.scrollDelta.dy != 0) {
            final delta = signal.scrollDelta.dy;
            final target = (_controller.offset + delta).clamp(
                _controller.position.minScrollExtent,
                _controller.position.maxScrollExtent);
            _controller.jumpTo(target);
          }
        },
        child: ScrollConfiguration(
          // Enable drag-to-scroll with mouse + trackpad on desktop/web;
          // the default MaterialScrollBehavior only accepts touch and
          // stylus so the strip was inert with a mouse.
          behavior: const _DayStripScrollBehavior(),
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: _range * 2 + 1,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemExtent: _cellWidth,
            itemBuilder: (ctx, i) {
              final date = _dateAtIndex(i);
              final dateKey = _dateOnly(date);
              final monthKey = DateTime(date.year, date.month, 1);
              final isSelected = _sameDay(date, widget.selected);
              final isToday = _sameDay(date, widget.today);
              final hasLessons = widget.lessonsByDate.contains(dateKey);
              final hasOverride = widget.overrideDates.contains(dateKey);
              final hasNote = widget.notedDates.contains(dateKey);
              final notifColors =
                  widget.notifColorsByDate[dateKey] ?? const <Color>[];
              final hasNotif = notifColors.isNotEmpty;
              final monthLoaded = widget.loadedMonths.contains(monthKey);

              Color fill;
              if (isSelected) {
                fill = c.scheduleSelected;
              } else if (!monthLoaded) {
                // Data hasn't arrived yet for this date's month — paint a
                // neutral surface so the cell doesn't masquerade as a known
                // "no lessons" day while a fetch is still in flight.
                fill = c.scheduleNoLessonsOutMonth;
              } else if (mode == DayColoringMode.evenOdd) {
                if (hasLessons) {
                  fill = _isEvenWeek(date)
                      ? c.scheduleEvenWeek
                      : c.scheduleOddWeek;
                } else {
                  fill = c.scheduleNoLessonsInMonth;
                }
              } else {
                fill = hasLessons
                    ? c.scheduleHasLessons
                    : c.scheduleNoLessonsInMonth;
              }
              final Color textColor;
              if (isSelected) {
                textColor = c.scheduleSelectedText;
              } else if (!monthLoaded) {
                textColor = c.scheduleOutMonthText;
              } else if (isToday) {
                textColor = c.scheduleSelected;
              } else {
                textColor = c.scheduleInMonthText;
              }
              final weekdayLabel = _weekdayShort(l10n, (date.weekday - 1) % 7);
              Border? border;
              if (isToday && !isSelected) {
                border = Border.all(color: c.scheduleTodayRing, width: 1.5);
              } else if (hasNote && !isSelected) {
                border = Border.all(
                    color: _noteOutline(
                        fill, Theme.of(context).brightness == Brightness.dark),
                    width: 2);
              }

              void selectDate() {
                ref.read(selectedDateProvider.notifier).set(_dateOnly(date));
                final firstOfTapped = DateTime(date.year, date.month, 1);
                ref.read(displayedMonthProvider.notifier).set(firstOfTapped);
                ref.read(stripVisibleMonthProvider.notifier).set(firstOfTapped);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: GestureDetector(
                  onLongPress: canAuthorNote
                      ? () {
                          HapticFeedback.mediumImpact();
                          selectDate();
                          _openNoteDialog(context, ref, _dateOnly(date));
                        }
                      : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: selectDate,
                    child: _WeekStripCell(
                      fill: fill,
                      border: border,
                      textColor: textColor,
                      weekdayLabel: weekdayLabel,
                      dayOfMonth: date.day,
                      hasOverride: hasOverride,
                      overrideColor: c.scheduleOverride,
                      hasNotif: hasNotif,
                      notifColors: notifColors,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Enables mouse + trackpad drag-scroll on desktop/web for the day strip.
/// Default [MaterialScrollBehavior.dragDevices] is `{touch, stylus}` only.
class _DayStripScrollBehavior extends MaterialScrollBehavior {
  const _DayStripScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

class _WeekStripCell extends StatelessWidget {
  const _WeekStripCell({
    required this.fill,
    required this.border,
    required this.textColor,
    required this.weekdayLabel,
    required this.dayOfMonth,
    required this.hasOverride,
    required this.overrideColor,
    required this.hasNotif,
    required this.notifColors,
  });

  final Color fill;
  final Border? border;
  final Color textColor;
  final String weekdayLabel;
  final int dayOfMonth;
  final bool hasOverride;
  final Color overrideColor;
  final bool hasNotif;
  final List<Color> notifColors;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dayOfMonth',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasOverride)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: overrideColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
    return hasNotif
        ? _AccentOutlineWrap(colors: notifColors, radius: 10, child: inner)
        : inner;
  }
}

Color _noteOutline(Color fill, bool isDark) {
  final hsl = HSLColor.fromColor(fill);
  final delta = isDark ? 0.25 : -0.25;
  return hsl
      .withLightness((hsl.lightness + delta).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
      .toColor();
}

/// Calendar day outline that uses a single color for one pin or splits the
/// border into equal segments around the perimeter when multiple pins with
/// different colors land on the same date. Starts at the top edge and walks
/// clockwise so a 2-color split reads as a top-left / bottom-right diagonal
/// after the squared corner.
class _AccentOutlineWrap extends StatelessWidget {
  const _AccentOutlineWrap({
    required this.colors,
    required this.radius,
    required this.child,
  });
  final List<Color> colors;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final unique = <Color>[];
    for (final c in colors) {
      if (!unique.contains(c)) unique.add(c);
    }
    if (unique.length <= 1) {
      final color = unique.isEmpty
          ? AppPalette.of(context).notificationIndicator
          : unique.first;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius + 2),
          border: Border.all(color: color, width: 2),
        ),
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      );
    }
    return CustomPaint(
      foregroundPainter: _SegmentedOutlinePainter(
        colors: unique,
        radius: radius + 2,
        strokeWidth: 2,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      ),
    );
  }
}

class _SegmentedOutlinePainter extends CustomPainter {
  _SegmentedOutlinePainter({
    required this.colors,
    required this.radius,
    required this.strokeWidth,
  });
  final List<Color> colors;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius - strokeWidth / 2),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    final segLen = total / colors.length;
    // Start at the top of the top edge (offset by 1/4 perimeter from origin
    // to land at roughly 12 o'clock, so a 2-way split produces a clean
    // top-left / bottom-right diagonal rather than a top/bottom split).
    final startOffset = total * 0.25;
    for (int i = 0; i < colors.length; i++) {
      final from = (startOffset + i * segLen) % total;
      final to = from + segLen;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = colors[i]
        ..strokeCap = StrokeCap.butt;
      _drawSegment(canvas, metrics, from, to, total, paint);
    }
  }

  void _drawSegment(Canvas canvas, List<ui.PathMetric> metrics, double from,
      double to, double total, Paint paint) {
    if (to <= total) {
      _extract(canvas, metrics, from, to, paint);
    } else {
      _extract(canvas, metrics, from, total, paint);
      _extract(canvas, metrics, 0, to - total, paint);
    }
  }

  void _extract(Canvas canvas, List<ui.PathMetric> metrics, double from,
      double to, Paint paint) {
    double cursor = 0;
    for (final m in metrics) {
      final end = cursor + m.length;
      if (from < end && to > cursor) {
        final a = (from - cursor).clamp(0.0, m.length);
        final b = (to - cursor).clamp(0.0, m.length);
        final sub = m.extractPath(a, b);
        canvas.drawPath(sub, paint);
      }
      cursor = end;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedOutlinePainter old) =>
      old.colors != colors ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

class _LegendRow extends ConsumerWidget {
  const _LegendRow({required this.shablonPattern});
  final ShablonWeekdayPattern shablonPattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final rawMode = ref.watch(dayColoringModeProvider).asData?.value ??
        DayColoringMode.auto;
    final mode = rawMode == DayColoringMode.auto
        ? (shablonPattern.hasEvenOddSplit
            ? DayColoringMode.evenOdd
            : DayColoringMode.hasLessons)
        : rawMode;
    Widget chip(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: c.mutedLabel)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: mode == DayColoringMode.hasLessons
            ? [
                chip(c.scheduleHasLessons, l10n.scheduleHasLessons),
                chip(c.scheduleNoLessonsInMonth, l10n.scheduleNoLessons),
              ]
            : [
                chip(c.scheduleOddWeek, l10n.scheduleWeekOdd),
                chip(c.scheduleEvenWeek, l10n.scheduleWeekEven),
                chip(c.scheduleNoLessonsInMonth, l10n.scheduleNoLessons),
              ],
      ),
    );
  }
}

/// Computed plan for rendering a day's lesson list. Pulled out so the
/// regular widget ([_DayLessons], used in the embed Column) and the sliver
/// variant ([_DayLessonsSlivers], used in the CustomScrollView paths) share
/// the same shape decisions without duplicating logic.
class _DayPlan {
  _DayPlan({
    required this.byOrdinal,
    required this.visibleSlots,
    required this.timeline,
    required this.now,
    required this.noFilter,
    required this.entriesEmpty,
  });
  final Map<int, List<RaspisanieEntry>> byOrdinal;
  final List<LessonSlot> visibleSlots;
  final _TimelineLayout? timeline;
  final DateTime now;
  final bool noFilter;
  final bool entriesEmpty;
}

_DayPlan _buildDayPlan({
  required DateTime date,
  required List<RaspisanieEntry> entries,
  required bool hideEmpty,
  required bool noFilter,
  required DateTime currentNow,
}) {
  final byOrdinal = <int, List<RaspisanieEntry>>{};
  for (final e in entries) {
    byOrdinal.putIfAbsent(e.subjectNumber, () => []).add(e);
  }
  // Merge the fixed table with any stray ordinals we only learn about from
  // entries (e.g. `subjectNumber: 11` from an irregular raspisanie row).
  final extraOrdinals = byOrdinal.keys
      .where((o) => !lessonSlots.any((s) => s.ordinal == o))
      .toList()
    ..sort();
  final allSlots = <LessonSlot>[
    ...lessonSlots,
    for (final o in extraOrdinals) slotForOrdinal(o),
  ];
  // Slots 6+ (evening/irregular) always hide when empty; slots 1-5 honor the
  // "hide empty" preference.
  final visibleSlots = allSlots.where((s) {
    final hasContent = byOrdinal[s.ordinal]?.isNotEmpty ?? false;
    if (s.ordinal >= 6) return hasContent;
    if (hideEmpty) return hasContent;
    return true;
  }).toList();
  final showTimeline = _sameDay(date, currentNow);
  final now = showTimeline ? currentNow : DateTime(0);
  final timeline = showTimeline ? _buildTimeline(now, visibleSlots) : null;
  return _DayPlan(
    byOrdinal: byOrdinal,
    visibleSlots: visibleSlots,
    timeline: timeline,
    now: now,
    noFilter: noFilter,
    entriesEmpty: entries.isEmpty,
  );
}

String _formatSelectedDate(AppLocalizations l10n, DateTime d) {
  return l10n.scheduleSelectedDate(
    d.day,
    _monthGen(l10n, d.month),
    _weekdayLong(l10n, d.weekday),
  );
}

/// Sliver variant — used inside CustomScrollView so the per-slot rows
/// inflate lazily as the user scrolls (1.2.11 Item 2d). The 1.2.10
/// in-card lazy-build only fired on subgroup-heavy slots; the OUTER loop
/// over slots was still eager. Recon flagged this as the dominant
/// eager-inflation cost on cold start.
class _DayLessonsSlivers extends ConsumerWidget {
  const _DayLessonsSlivers({required this.date, required this.entries});
  final DateTime date;
  final List<RaspisanieEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hideEmpty = ref.watch(hideEmptySlotsProvider).asData?.value ?? false;
    final noFilter = ref.watch(scheduleFiltersProvider).isEmpty;
    final currentNow = ref.watch(nowProvider);
    final plan = _buildDayPlan(
      date: date,
      entries: entries,
      hideEmpty: hideEmpty,
      noFilter: noFilter,
      currentNow: currentNow,
    );

    final today = _dateOnly(currentNow);
    final headerSliver = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _formatSelectedDate(l10n, date),
                maxLines: 2,
                softWrap: true,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppPalette.of(context).dayHeadingText,
                ),
              ),
            ),
            _DayHeaderTrailing(date: date, today: today),
          ],
        ),
      ),
    );

    // Cross-axis centering. Reads the *local* sliver cross-axis extent rather
    // than MediaQuery — the wide-PC layout puts this CustomScrollView inside
    // an Expanded(flex:5) of a Row, so window width != sliver width. Using
    // MediaQuery here produced 1220px of padding inside a 1066px column on
    // 1920-wide viewports, crushing content to zero width (1.2.13 fix).
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossExtent = constraints.crossAxisExtent;
        final hPad = crossExtent > _lessonListMaxWidth + 24
            ? (crossExtent - _lessonListMaxWidth) / 2
            : 12.0;
        final outerPadding = EdgeInsets.fromLTRB(hPad, 8, hPad, 8);

        if (plan.noFilter) {
          return SliverPadding(
            padding: outerPadding,
            sliver: SliverMainAxisGroup(slivers: [
              headerSliver,
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                  child: Text(
                    l10n.scheduleNoFilterPicked,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppPalette.of(context).mutedLabel,
                    ),
                  ),
                ),
              ),
            ]),
          );
        }

        // Pre-compute the row-by-row spec so SliverList.builder can lazy-inflate
        // exactly the rows entering the viewport. Each entry is either a "you
        // are here" divider or a slot row.
        final rows = <_SlotRowSpec>[];
        for (final slot in plan.visibleSlots) {
          if (plan.timeline != null &&
              plan.timeline!.breakBeforeOrdinal == slot.ordinal) {
            rows.add(const _SlotRowSpec.youAreHere());
          }
          rows.add(_SlotRowSpec.slot(slot));
        }

        final slotsSliver = SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final spec = rows[i];
            if (spec.isYouAreHere) return const _YouAreHere();
            final slot = spec.slot!;
            return _SlotRow(
              slot: slot,
              entries: plan.byOrdinal[slot.ordinal] ?? const [],
              state: plan.timeline?.stateFor(slot.ordinal) ??
                  _LessonPeriodState.idle,
              label: plan.timeline?.labelFor(l10n, slot.ordinal, plan.now),
              progress: plan.timeline?.progressFor(slot.ordinal, plan.now),
            );
          },
        );

        return SliverPadding(
          padding: outerPadding,
          sliver: SliverMainAxisGroup(slivers: [
            headerSliver,
            slotsSliver,
            if (plan.entriesEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Text(
                    l10n.scheduleNoLessonsOnDay,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.of(context).mutedLabel,
                    ),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _SlotRowSpec {
  const _SlotRowSpec.youAreHere()
      : slot = null,
        isYouAreHere = true;
  const _SlotRowSpec.slot(LessonSlot s)
      : slot = s,
        isYouAreHere = false;
  final LessonSlot? slot;
  final bool isYouAreHere;
}

class _DayLessons extends ConsumerWidget {
  const _DayLessons({required this.date, required this.entries});
  final DateTime date;
  final List<RaspisanieEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hideEmpty = ref.watch(hideEmptySlotsProvider).asData?.value ?? false;
    final noFilter = ref.watch(scheduleFiltersProvider).isEmpty;
    final currentNow = ref.watch(nowProvider);
    final plan = _buildDayPlan(
      date: date,
      entries: entries,
      hideEmpty: hideEmpty,
      noFilter: noFilter,
      currentNow: currentNow,
    );

    final today = _dateOnly(currentNow);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _lessonListMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _formatSelectedDate(l10n, date),
                        maxLines: 2,
                        softWrap: true,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppPalette.of(context).dayHeadingText,
                        ),
                      ),
                    ),
                    _DayHeaderTrailing(date: date, today: today),
                  ],
                ),
              ),
              if (plan.noFilter)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                  child: Text(
                    l10n.scheduleNoFilterPicked,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppPalette.of(context).mutedLabel,
                    ),
                  ),
                )
              else ...[
                for (final slot in plan.visibleSlots) ...[
                  if (plan.timeline != null &&
                      plan.timeline!.breakBeforeOrdinal == slot.ordinal)
                    const _YouAreHere(),
                  _SlotRow(
                    slot: slot,
                    entries: plan.byOrdinal[slot.ordinal] ?? const [],
                    state: plan.timeline?.stateFor(slot.ordinal) ??
                        _LessonPeriodState.idle,
                    label:
                        plan.timeline?.labelFor(l10n, slot.ordinal, plan.now),
                    progress:
                        plan.timeline?.progressFor(slot.ordinal, plan.now),
                  ),
                ],
                if (plan.entriesEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Text(
                      l10n.scheduleNoLessonsOnDay,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.of(context).mutedLabel,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _LessonPeriodState { idle, current, next }

class _TimelineLayout {
  _TimelineLayout({
    required this.stateByOrdinal,
    required this.breakBeforeOrdinal,
    required this.endTimes,
    required this.startTimes,
  });

  final Map<int, _LessonPeriodState> stateByOrdinal;
  final int? breakBeforeOrdinal;
  final Map<int, DateTime> endTimes;
  final Map<int, DateTime> startTimes;

  _LessonPeriodState stateFor(int ordinal) =>
      stateByOrdinal[ordinal] ?? _LessonPeriodState.idle;

  /// Fraction of the lesson that has elapsed at `now` (0..1). Null unless the
  /// ordinal is currently in progress.
  double? progressFor(int ordinal, DateTime now) {
    if (stateFor(ordinal) != _LessonPeriodState.current) return null;
    final start = startTimes[ordinal];
    final end = endTimes[ordinal];
    if (start == null || end == null) return null;
    final total = end.difference(start).inSeconds;
    if (total <= 0) return null;
    final elapsed = now.difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String? labelFor(AppLocalizations l10n, int ordinal, DateTime now) {
    final s = stateFor(ordinal);
    if (s == _LessonPeriodState.current) {
      final end = endTimes[ordinal];
      if (end == null) return l10n.scheduleNowOngoing;
      final mins = end.difference(now).inMinutes;
      if (mins <= 0) return l10n.scheduleNowOngoing;
      if (mins <= 5) return l10n.scheduleNowEndsInMin(mins);
      return l10n.scheduleNowOngoingUntil(formatDuration(l10n, mins));
    }
    if (s == _LessonPeriodState.next) {
      final start = startTimes[ordinal];
      if (start == null) return null;
      final mins = start.difference(now).inMinutes;
      if (mins <= 0) return null;
      return l10n.scheduleStartsIn(formatDuration(l10n, mins));
    }
    return null;
  }
}

_TimelineLayout _buildTimeline(DateTime now, List<LessonSlot> slots) {
  final today = DateTime(now.year, now.month, now.day);
  final states = <int, _LessonPeriodState>{};
  final ends = <int, DateTime>{};
  final starts = <int, DateTime>{};

  int? currentOrdinal;
  int? nextOrdinal;
  int? lastCompletedOrdinal;

  for (final s in slots) {
    if (!s.hasTime) continue;
    final start = _parseTime(today, s.start!);
    final end = _parseTime(today, s.end!);
    starts[s.ordinal] = start;
    ends[s.ordinal] = end;
    if (!now.isBefore(start) && now.isBefore(end)) {
      currentOrdinal = s.ordinal;
    } else if (now.isBefore(start) && nextOrdinal == null) {
      nextOrdinal = s.ordinal;
    } else if (!now.isBefore(end)) {
      lastCompletedOrdinal = s.ordinal;
    }
  }

  if (currentOrdinal != null) {
    states[currentOrdinal] = _LessonPeriodState.current;
  }
  if (nextOrdinal != null && currentOrdinal == null) {
    states[nextOrdinal] = _LessonPeriodState.next;
  }

  int? breakBefore;
  if (currentOrdinal == null &&
      nextOrdinal != null &&
      lastCompletedOrdinal != null) {
    breakBefore = nextOrdinal;
  }

  return _TimelineLayout(
    stateByOrdinal: states,
    breakBeforeOrdinal: breakBefore,
    startTimes: starts,
    endTimes: ends,
  );
}

DateTime _parseTime(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(
      day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
}

class _YouAreHere extends StatelessWidget {
  const _YouAreHere();
  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c.scheduleSelected,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1.5,
              color: c.scheduleSelected.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).scheduleNow,
            style: TextStyle(
              fontSize: 11,
              color: c.scheduleSelected,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.entries,
    required this.state,
    this.label,
    this.progress,
  });
  final LessonSlot slot;
  final List<RaspisanieEntry> entries;
  final _LessonPeriodState state;
  final String? label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (slot.hasTime) ...[
                  Text(
                    slot.start!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: c.lessonCardTitle,
                    ),
                  ),
                  Text(
                    slot.end!,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: c.lessonCardSubtitle,
                    ),
                  ),
                ] else
                  Text(
                    l10n.schedulePairOrdinal(slot.ordinal),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: c.lessonCardTitle,
                    ),
                  ),
                if (slot.hasTime)
                  Text(
                    l10n.scheduleOrdinalPair(slot.ordinal),
                    style: TextStyle(
                      fontSize: 11,
                      color: c.emptySlotText,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const _EmptySlot()
                : entries.length >= 5
                    // Subgroup-heavy slot — lazy-build per-card to keep the
                    // outer scroll view's first-frame cost down. Below the
                    // threshold the eager Column wins (cheaper than a sliver
                    // setup for 1–4 children, and preserves the original
                    // IntrinsicHeight semantics).
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        itemBuilder: (context, i) => _LessonCard(
                          entry: entries[i],
                          state: state,
                          label: label,
                          progress: progress,
                        ),
                      )
                    : Column(
                        children: [
                          for (final e in entries)
                            _LessonCard(
                              entry: e,
                              state: state,
                              label: label,
                              progress: progress,
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// Shared slot row height. Both [_EmptySlot] and [_LessonCard] use *exactly*
/// this value (fixed, not min) as their outer envelope so a day with a mix
/// of empty and filled slots lines up as a consistent grid. The filled
/// card's inner content (title + subtitle, optionally + progress label) is
/// designed to fit within this envelope; anything beyond clips rather than
/// growing the row — losing a line of subtitle is preferable to misaligned
/// rows, which read as a broken grid.
const double _kSlotRowHeight = 68.0;

/// Outer vertical margin around every slot (empty and filled). Centralised
/// so both variants share an identical outer envelope — the old "minHeight
/// on filled, fixed height on empty" pairing left a visible 4 px drift on
/// mixed days.
const EdgeInsets _kSlotRowMargin = EdgeInsets.symmetric(vertical: 2);

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();
  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    return PaletteRegion(
      token: PaletteTokens.emptySlotFill,
      child: Container(
        height: _kSlotRowHeight,
        margin: _kSlotRowMargin,
        decoration: BoxDecoration(
          color: c.emptySlotFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.emptySlotBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          '—',
          style: TextStyle(fontSize: 14, color: c.emptySlotText),
        ),
      ),
    );
  }
}

class _LessonCard extends ConsumerStatefulWidget {
  const _LessonCard({
    required this.entry,
    required this.state,
    this.label,
    this.progress,
  });
  final RaspisanieEntry entry;
  final _LessonPeriodState state;
  final String? label;
  final double? progress;

  @override
  ConsumerState<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends ConsumerState<_LessonCard> {
  // When true, subject + teacher Text widgets drop their maxLines/ellipsis
  // limits so a long subject name (or long teacher name) wraps to as many
  // lines as needed and the card grows vertically. Toggled by long-press;
  // a second long-press collapses again. State lives inside the card so
  // it resets naturally when the day changes (the widget tree rebuilds
  // with fresh _LessonCard instances at new positions). No auto-collapse
  // on tap or scroll — least-surprise per the 1.2.7 spec.
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final state = widget.state;
    final label = widget.label;
    final progress = widget.progress;
    final l10n = AppLocalizations.of(context);
    // Teacher name is the Flexible/ellipsized element — group id + optional
    // subgroup marker always stay visible to the right because they're short
    // and load-bearing (users pick a row by group first). Room + time are
    // handled outside this column and always render.
    final tailParts = <String>[
      entry.group.name,
      if (entry.subgroup != null)
        l10n.scheduleSubgroup(entry.subgroup.toString()),
    ];
    final subtitleTail = ' · ${tailParts.join(' · ')}';

    final c = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeFill = c.lessonBadgeFill;
    final badgeText = c.lessonBadgeText;

    final isCurrent = state == _LessonPeriodState.current;
    final isNext = state == _LessonPeriodState.next;

    // Override rows no longer tint the card background or border — the amber
    // wash drowned out the current/next parity cues and looked like a system
    // warning. The small amber dot beside the subject (below) is the sole
    // signal now, which reads as an annotation rather than a state.
    final overrideTint = c.scheduleOverride;
    final fill = isCurrent
        ? Color.alphaBlend(c.scheduleSelected.withOpacity(isDark ? 0.28 : 0.14),
            c.lessonCardFill)
        : c.lessonCardFill;
    final borderColor = isCurrent
        ? c.scheduleSelected
        : (isNext ? c.scheduleSelected.withOpacity(0.4) : c.lessonCardBorder);

    final scheme = Theme.of(context).colorScheme;
    // 1.3.3 Item 6: lesson progress fill is opt-out via Settings (default
    // ON preserves historic behaviour). When OFF the "Идёт сейчас" status
    // label and the current-lesson border / accent strip still render —
    // only the left-to-right fill behind the card content is suppressed.
    final progressEnabled =
        ref.watch(showLessonProgressProvider).asData?.value ?? true;
    final showProgress = isCurrent && progress != null && progressEnabled;
    // Fixed height matches _EmptySlot exactly so mixed empty/filled rows line
    // up as a consistent grid — except when a status label is rendered
    // ("Идёт сейчас …" on the current lesson, "Начнётся через …" on the next)
    // OR the user has long-pressed to expand this card. Those rows switch to
    // a min-height envelope so the extra content (status label, full subject
    // name, full teacher name) can push the card taller without clipping.
    // Gating on the same `grows` flag keeps the states in sync and leaves
    // every other row at _kSlotRowHeight, preserving grid cadence above and
    // below. The slot-ordinal/time column to the left uses
    // CrossAxisAlignment.start, so it stays top-aligned when the card grows.
    final grows = label != null || _expanded;
    final card = Container(
      margin: _kSlotRowMargin,
      constraints: const BoxConstraints(minHeight: _kSlotRowHeight),
      height: grows ? null : _kSlotRowHeight,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 1),
      ),
      clipBehavior: showProgress ? Clip.antiAlias : Clip.none,
      child: Stack(
        children: [
          if (showProgress)
            // 1.2.9 lag fix 3b: was AnimatedFractionallySizedBox with a
            // 400ms easeOut curve. The animation restarted on every
            // nowProvider tick (every 30s) and triggered a re-paint of
            // every visible current-lesson card. Switched to a static
            // FractionallySizedBox: width updates jump-cut to the new
            // progress fraction, which is invisible at 30s tick rate
            // anyway. Removes the per-tick animation cost entirely.
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  color: scheme.primary.withOpacity(isDark ? 0.20 : 0.15),
                ),
              ),
            ),
          // 1.2.9 lag fix 3c: accent strip lifted out of the Row +
          // IntrinsicHeight pair. IntrinsicHeight forced an extra layout
          // measurement pass per card on every build to size the
          // stretched Row; the strip itself was the only stretched
          // child. Re-rendered as a Positioned overlay filling the card
          // height, the strip needs no measurement and the Row + the
          // wrapping IntrinsicHeight both disappear.
          if (isCurrent)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.scheduleSelected,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                  ),
                ),
              ),
            ),
          // SizedBox(width:double.infinity) keeps the Padding (and the
          // Row inside its Column) stretched to the card's full width
          // even though it's no longer wrapped in Expanded — Stack's
          // non-positioned children otherwise shrink to their intrinsic
          // size, which would break the Flexible(Text) ellipsis logic.
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.fromLTRB(isCurrent ? 16 : 12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.subject.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: c.lessonCardTitle,
                          ),
                          maxLines: _expanded ? null : 1,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isOverride) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: overrideTint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.classroom,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.teacher.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.lessonCardSubtitle,
                          ),
                          maxLines: _expanded ? null : 1,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        subtitleTail,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.lessonCardSubtitle,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.scheduleSelected,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    // 1.3.6: always wrap in AnimatedSize. The 1.2.9 conditional-wrap perf
    // optimisation was reverted because it broke the long-press expansion
    // animation: the FIRST flip into `grows == true` mounted a fresh
    // AnimatedSize already at the expanded size, so the very transition
    // the user sees jump-cuts (only subsequent height changes within the
    // same expanded session animated). The animation matters more than the
    // marginal rebuild cost saved on stable cards.
    final Widget heightStable = AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: card,
    );
    final gestured = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _toggleExpanded,
      child: heightStable,
    );
    final regioned = PaletteRegion(
      token: PaletteTokens.lessonCardFill,
      child: gestured,
    );
    if (entry.isOverride) {
      // triggerMode: tap so the "Изменено" tooltip fires on a quick tap and
      // long-press is reserved for our expand toggle. Without this, Tooltip's
      // default longPress trigger would race the GestureDetector for override
      // rows; tap-trigger keeps both gestures available without conflict.
      return Tooltip(
        message: l10n.scheduleOverrideIndicator,
        triggerMode: TooltipTriggerMode.tap,
        waitDuration: const Duration(milliseconds: 400),
        child: regioned,
      );
    }
    return regioned;
  }
}

class _DayNoteSection extends ConsumerWidget {
  const _DayNoteSection({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final day = _dateOnly(date);
    final async = ref.watch(dayNoteProvider(day));
    final note = async.asData?.value;
    if (note == null || note.body.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final queuedOps =
        ref.watch(noteQueueProvider).asData?.value ?? const <QueuedNoteOp>[];
    final isQueued = queuedOpForDate(queuedOps, day) != null;
    final c = AppPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _lessonListMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: PaletteRegion(
            token: PaletteTokens.noteBackground,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
              decoration: BoxDecoration(
                color: c.noteBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.noteBorder, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sticky_note_2_outlined,
                          size: 16, color: c.noteForeground),
                      const SizedBox(width: 6),
                      Text(
                        l10n.scheduleNoteLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: c.noteForeground,
                        ),
                      ),
                      if (isQueued) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: l10n.scheduleNoteOfflineHint,
                          child: Icon(
                            Icons.sync,
                            size: 14,
                            color: c.noteForeground.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      const Spacer(),
                      TextButton(
                        onPressed: () => _openNoteDialog(context, ref, day),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(l10n.commonEdit),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 2, 4, 0),
                    child: SelectableText(
                      note.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.noteForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedNotesSection extends ConsumerWidget {
  const _PinnedNotesSection({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final day = _dateOnly(date);
    final async = ref.watch(pinnedNotesProvider(day));
    final pins = async.asData?.value ?? const <PinnedDayNote>[];
    if (pins.isEmpty) return const SizedBox.shrink();
    final user = ref.watch(currentUserProvider);
    final heading = pins.length == 1
        ? l10n.schedulePinnedNoteSingle
        : l10n.schedulePinnedNoteMany;
    final c = AppPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _lessonListMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  children: [
                    Icon(Icons.push_pin_outlined,
                        size: 16, color: c.mutedLabel),
                    const SizedBox(width: 6),
                    Text(
                      heading,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: c.dayHeadingText,
                      ),
                    ),
                  ],
                ),
              ),
              for (final pin in pins)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PinnedNoteCard(pin: pin, currentUser: user),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedNoteCard extends ConsumerWidget {
  const _PinnedNoteCard({required this.pin, required this.currentUser});
  final PinnedDayNote pin;
  final AppUser? currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwn = currentUser != null && currentUser!.id == pin.sender.id;
    final isAdmin = currentUser?.role == UserRole.admin;
    final canDelete = isOwn || isAdmin;
    final accent = accentColorOf(pin.sender.accentColor, isDark: isDark);

    return PaletteRegion(
      token: PaletteTokens.lessonCardFill,
      child: Container(
        decoration: BoxDecoration(
          color: c.lessonCardFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.lessonCardBorder),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, canDelete ? 4 : 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _SenderRoleChip(role: pin.sender.role),
                          const SizedBox(width: 6),
                          // Expanded so the login text consumes all space
                          // between the role chip and the trailing group —
                          // pushing the date + delete cluster flush to the
                          // card's right padding.
                          Expanded(
                            child: Text(
                              pin.sender.login,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.lessonCardTitle,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativePinTime(l10n, pin.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.lessonCardSubtitle,
                            ),
                          ),
                          if (canDelete) ...[
                            const SizedBox(width: 4),
                            SizedBox(
                              height: 28,
                              width: 28,
                              child: IconButton(
                                tooltip:
                                    AppLocalizations.of(context).commonDelete,
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: accent,
                                ),
                                onPressed: () => _confirmDelete(context, ref),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        pin.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.lessonCardTitle,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.scheduleDeleteNoteConfirmTitle),
        content: Text(l10n.scheduleDeleteNoteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(notificationsProvider.notifier).delete(pin.notificationId);
    } catch (e) {
      TopBanner.showError(_prettyNoteError(l10n, e));
    }
  }
}

class _SenderRoleChip extends StatelessWidget {
  const _SenderRoleChip({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, label) = switch (role) {
      UserRole.admin => (
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
          l10n.roleChipAdmin,
        ),
      UserRole.teacher => (
          const Color(0xFFDBEAFE),
          const Color(0xFF1E40AF),
          l10n.roleChipTeacher,
        ),
      UserRole.student => (
          const Color(0xFFE5E7EB),
          const Color(0xFF374151),
          l10n.roleChipStudent,
        ),
      UserRole.system => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          l10n.roleChipSystem,
        ),
    };
    final darkBg = switch (role) {
      UserRole.admin => const Color(0xFF7F1D1D),
      UserRole.teacher => const Color(0xFF1E3A8A),
      UserRole.student => const Color(0xFF374151),
      UserRole.system => const Color(0xFF78350F),
    };
    final darkFg = switch (role) {
      UserRole.admin => const Color(0xFFFECACA),
      UserRole.teacher => const Color(0xFFBFDBFE),
      UserRole.student => const Color(0xFFE5E7EB),
      UserRole.system => const Color(0xFFFDE68A),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? darkBg : bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? darkFg : fg,
        ),
      ),
    );
  }
}

String _relativePinTime(AppLocalizations l10n, DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(when.year, when.month, when.day);
  final diff = today.difference(d).inDays;
  final hh = when.hour.toString().padLeft(2, '0');
  final mm = when.minute.toString().padLeft(2, '0');
  final hhmm = '$hh:$mm';
  if (diff == 0) return l10n.scheduleRelToday(hhmm);
  if (diff == 1) return l10n.scheduleRelYesterday(hhmm);
  if (diff < 7) return l10n.scheduleRelDaysAgo(diff);
  return '${when.day}.${when.month.toString().padLeft(2, '0')}.${when.year}';
}

class _DebugClockPill extends ConsumerWidget {
  const _DebugClockPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final override = ref.watch(debugClockProvider).asData?.value;
    if (override == null) return const SizedBox.shrink();
    final d = override;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final label = l10n.scheduleNoteTime(
      d.day,
      _monthShort(l10n, d.month),
      '$hh:$mm',
    );
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      shape: StadiumBorder(
        side: BorderSide(color: scheme.tertiary.withOpacity(0.4)),
      ),
      elevation: 2,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => ref.read(debugClockProvider.notifier).clear(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 14, color: scheme.onTertiaryContainer),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.close, size: 14, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).asData?.value ?? true;
    if (online) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 16, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.scheduleOfflineBanner,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openNoteDialog(
    BuildContext context, WidgetRef ref, DateTime date) async {
  final day = _dateOnly(date);
  // Notes are backed by an offline-write queue, so we let the user open
  // the dialog even when offline and authed — the save will queue and
  // flush once connectivity returns.
  final existing = ref.read(dayNoteProvider(day)).asData?.value;
  final controller = TextEditingController(text: existing?.body ?? '');
  final storage = ref.read(noteStorageProvider);
  final l10n = AppLocalizations.of(context);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          bool busy = false;

          Future<void> onSave() async {
            setState(() => busy = true);
            try {
              await storage.set(day, controller.text);
              ref.invalidate(dayNoteProvider(day));
              ref.invalidate(
                  monthNotesByMonthProvider(ref.read(displayedMonthProvider)));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (e) {
              // Refresh outlines either way — the storage layer clears any
              // optimistic queue entry on server rejection.
              ref.invalidate(dayNoteProvider(day));
              ref.invalidate(
                  monthNotesByMonthProvider(ref.read(displayedMonthProvider)));
              setState(() => busy = false);
              TopBanner.showError(_prettyNoteError(l10n, e));
            }
          }

          Future<void> onDelete() async {
            setState(() => busy = true);
            try {
              await storage.delete(day);
              ref.invalidate(dayNoteProvider(day));
              ref.invalidate(
                  monthNotesByMonthProvider(ref.read(displayedMonthProvider)));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (e) {
              ref.invalidate(dayNoteProvider(day));
              ref.invalidate(
                  monthNotesByMonthProvider(ref.read(displayedMonthProvider)));
              setState(() => busy = false);
              TopBanner.showError(_prettyNoteError(l10n, e));
            }
          }

          return AlertDialog(
            title: Text(
              l10n.scheduleNoteForDay(_formatDayHeader(l10n, day)),
              style: const TextStyle(fontSize: 15),
            ),
            content: SizedBox(
              width: 360,
              child: TextField(
                controller: controller,
                minLines: 4,
                maxLines: 10,
                autofocus: true,
                enabled: !busy,
                decoration: InputDecoration(
                  hintText: l10n.scheduleNoteHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: busy ? null : onDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(l10n.commonDelete),
                ),
              TextButton(
                onPressed:
                    busy ? null : () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: busy ? null : onSave,
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatDayHeader(AppLocalizations l10n, DateTime d) {
  return '${d.day} ${_monthGen(l10n, d.month)} ${d.year}';
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              l10n.scheduleLoadError(message),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

String _prettyNoteError(AppLocalizations l10n, Object e) {
  return _prettyScheduleError(l10n, e);
}

String _prettyScheduleError(AppLocalizations l10n, Object? e) {
  if (e is OperationException && e.graphqlErrors.isNotEmpty) {
    return e.graphqlErrors.first.message;
  }
  if (e is OperationException && e.linkException != null) {
    return l10n.scheduleNoConnection;
  }
  return l10n.commonErrorWith(e?.toString() ?? '');
}

// Thin pass-throughs to the public week-math helpers. Kept as
// underscore-private aliases so the existing ~30 callers in this file
// (and the new 1.3.0 week-list code) read consistently. The public
// implementations live in `lib/common/week_math.dart` for unit tests.
DateTime _dateOnly(DateTime d) => week_math.dateOnly(d);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _mondayOf(DateTime d) => week_math.mondayOf(d);

bool _sameWeek(DateTime a, DateTime b) => week_math.sameWeek(a, b);

bool _isEvenWeek(DateTime d) => week_math.isEvenWeek(d);

// =====================================================================
// 1.3.0 — Week-list schedule view
// =====================================================================
//
// Third schedule view alongside the grid (default) and the day-strip
// (1.1.1). Vertical scroll of the selected week's seven days, with a
// horizontal pill-row of week-range selectors at the top. Reuses the
// _LessonCard / _SlotRow / _DayNoteSection / _PinnedNotesSection
// machinery from grid mode so long-press expand, "Идёт сейчас",
// "Начнётся через", and override indicators all carry over.
//
// "Selected week" is derived from `selectedDateProvider` (no separate
// notifier) — picking a pill snaps `selectedDate` to that week's Monday,
// the existing "Сегодня" FAB still works, and any deep-link flow that
// sets `selectedDate` continues to land on the right week.
//
// Range guardrail: ±[_kWeekListRange] weeks from today's Monday, fixed
// (NOT infinite). The spec allowed an infinite scroll with ±2 lookahead;
// the static range is materially simpler, fits a full academic year in
// either direction, and removed a class of binding-edge bugs.

const int _kWeekListRange = 52;

/// 1.3.7 Item 3 — bumped by the "Сегодня" FAB so the week-list body can
/// scroll vertically to today's day section in addition to the existing
/// horizontal pill centring (which already happens via the
/// `selectedDateProvider` change). `ref.listen` on this provider in
/// [WeekListScheduleBody] reacts to each pulse with an `animateTo` on
/// the body's Scrollable. Outside the week-list view nothing listens,
/// so the pulse is a no-op.
class ReturnToTodayPulse extends Notifier<int> {
  @override
  int build() => 0;
  void pulse() => state = state + 1;
}

final returnToTodayPulseProvider =
    NotifierProvider<ReturnToTodayPulse, int>(ReturnToTodayPulse.new);

/// Body widget for the week-list view. Renders the week-pill selector
/// up top + a vertical list of the selected week's days. Wraps the
/// existing offline-banner / error / loading scaffolding the same way
/// the grid + day-strip paths do via [_ScheduleBody].
class WeekListScheduleBody extends ConsumerStatefulWidget {
  const WeekListScheduleBody({
    super.key,
    this.embed = false,
    this.filterTrailing,
  });
  final bool embed;
  final Widget? filterTrailing;

  @override
  ConsumerState<WeekListScheduleBody> createState() =>
      _WeekListScheduleBodyState();
}

class _WeekListScheduleBodyState extends ConsumerState<WeekListScheduleBody> {
  // 1.3.7 Item 3: marker for today's day section. The "Сегодня" FAB
  // pulses [returnToTodayPulseProvider]; the listener resolves this
  // key's RenderBox and animates the surrounding Scrollable so today's
  // section lands just below the sticky range header.
  final GlobalKey _todayKey = GlobalKey();

  void _scrollToTodaySection() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_doScrollToTodaySection()) return;
      // Single defensive retry: today's section should always be in
      // the tree by now (current week's days all render eagerly), but
      // give the layout one more frame in case route-visibility or
      // ConstrainedBox measurement deferred its first paint.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _doScrollToTodaySection();
      });
    });
  }

  bool _doScrollToTodaySection() {
    final ctx = _todayKey.currentContext;
    if (ctx == null) return false;
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return false;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return false;
    final viewportRender = scrollable.context.findRenderObject() as RenderBox?;
    if (viewportRender == null) return false;
    final dy =
        renderBox.localToGlobal(Offset.zero, ancestor: viewportRender).dy;
    final pos = scrollable.position;
    // Mobile uses a SliverPersistentHeader pinned at 28px; desktop has
    // the range header outside the scrollable, so it overlaps nothing.
    // 36px accounts for the mobile sticky + 8px breathing room and is
    // visually safe on desktop too (just shifts the section ~36px below
    // the viewport top).
    const stickyOffset = 36.0;
    final target = (pos.pixels + dy - stickyOffset)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if ((target - pos.pixels).abs() < 0.5) return true; // already there
    pos.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(returnToTodayPulseProvider, (_, __) {
      _scrollToTodaySection();
    });
    final embed = widget.embed;
    final filterTrailing = widget.filterTrailing;
    final selected = ref.watch(selectedDateProvider);
    final today = _dateOnly(ref.watch(nowProvider));
    final selectedWeek = _mondayOf(selected);
    final filters = ref.watch(scheduleFiltersProvider);

    // Months covered by the selected week (1 or 2 — Mon–Sun can straddle
    // a month boundary). Watch each one's raspisanie/notes/pinned providers
    // so the body re-renders as data settles. Reuses the family caches
    // populated by the grid/day-strip paths.
    final weekDays =
        List<DateTime>.generate(7, (i) => selectedWeek.add(Duration(days: i)));
    final touchedMonths = <DateTime>{};
    for (final d in weekDays) {
      touchedMonths.add(DateTime(d.year, d.month, 1));
    }

    final all = <RaspisanieEntry>[];
    final notedDates = <DateTime>{};
    final pinned = <DateTime, List<Color>>{};
    final loadedMonths = <DateTime>{};
    for (final m in touchedMonths) {
      final raspAsync = ref.watch(
          monthRaspisanieByMonthProvider(monthFilterParamsFor(m, filters)));
      final notesAsync = ref.watch(monthNotesByMonthProvider(m));
      final pinnedAsync = ref.watch(pinnedNotesForMonthProvider(m));
      final raspData = raspAsync.asData?.value;
      if (raspData != null) {
        all.addAll(raspData);
        loadedMonths.add(m);
      }
      final notesData = notesAsync.asData?.value;
      if (notesData != null) notedDates.addAll(notesData);
      final pinnedData = pinnedAsync.asData?.value;
      if (pinnedData != null) {
        pinnedData.forEach((k, v) {
          pinned.putIfAbsent(k, () => <Color>[]).addAll(v);
        });
      }
    }

    // Cross-month boundary weeks fetch two month providers whose grid
    // windows overlap; dedup before indexing so the same lesson doesn't
    // render twice on every slot.
    final entries = dedupRaspisanieEntries(all);
    final dayIndex = <DateTime, List<RaspisanieEntry>>{};
    for (final e in entries) {
      final key = _dateOnly(e.date);
      dayIndex.putIfAbsent(key, () => []).add(e);
    }
    final shablonPattern = shablonPatternFromEntries(entries);
    final weekHasAnyData =
        loadedMonths.containsAll(touchedMonths) || entries.isNotEmpty;

    // 1.3.2: PC layout matches Лента дней — constrain body to 700px and pull
    // notes (regular + pinned) into a 320px column on the right at >=1100px.
    // Below that threshold the body still constrains to a centered max-width
    // so it doesn't sprawl across the whole window; notes stay inline.
    final viewportWidth = MediaQuery.of(context).size.width;
    final isDesktopWeekList = viewportWidth >= 1100 && !embed;

    Widget buildBody({required bool inlineNotes}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in weekDays)
            _WeekDaySection(
              // 1.3.7 Item 3: GlobalKey on today's section only — the
              // FAB pulse handler resolves its RenderBox to scroll it
              // into view. Null on other days so the key never appears
              // in two places at once.
              key: _sameDay(d, today) ? _todayKey : null,
              date: d,
              today: today,
              entries: dayIndex[_dateOnly(d)] ?? const [],
              notedDates: notedDates,
              pinnedColors: pinned,
              inlineNotes: inlineNotes,
            ),
          if (!weekHasAnyData)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                AppLocalizations.of(context).scheduleNoDataForWeek,
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.of(context).mutedLabel,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      );
    }

    if (isDesktopWeekList) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(trailing: filterTrailing),
          _WeekPillSelector(
            today: today,
            selectedWeek: selectedWeek,
            shablonPattern: shablonPattern,
          ),
          _WeekRangeHeader(week: selectedWeek, today: today),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: _lessonListMaxWidth),
                  child: SingleChildScrollView(
                    child: buildBody(inlineNotes: false),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: _WeekListNotesColumn(weekDays: weekDays),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _FilterBar(trailing: filterTrailing)),
        SliverToBoxAdapter(
          child: _WeekPillSelector(
            today: today,
            selectedWeek: selectedWeek,
            shablonPattern: shablonPattern,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _WeekRangeHeaderDelegate(
            week: selectedWeek,
            today: today,
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _lessonListMaxWidth),
              child: buildBody(inlineNotes: true),
            ),
          ),
        ),
      ],
    );
  }
}

/// Right-rail notes column for the PC (>=1100px) week-list layout. Stacks
/// pinned + regular notes for each of the seven visible days; per-day
/// widgets self-hide via SizedBox.shrink when empty so the rail stays
/// quiet on weeks with no notes.
class _WeekListNotesColumn extends StatelessWidget {
  const _WeekListNotesColumn({required this.weekDays});
  final List<DateTime> weekDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        for (final d in weekDays) ...[
          _PinnedNotesSection(date: d),
          _DayNoteSection(date: d),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 1.3.5: small range + parity header rendered above the day list. Replaces
/// the 1.3.0 `_WeekBodyBackground` even/odd wash that proved too noisy in
/// the body — parity is now communicated by the selected pill plus this
/// label. Mobile uses a sliver-pinned variant ([_WeekRangeHeaderDelegate])
/// so it stays glued to the top while the day list scrolls; desktop puts
/// this inline above the body row (the body has its own scroll, so the
/// header is naturally fixed above it).
class _WeekRangeHeader extends StatelessWidget {
  const _WeekRangeHeader({required this.week, required this.today});
  final DateTime week;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final theme = Theme.of(context);
    final label = formatWeekRangeWithParity(l10n, week, today: today);
    return Container(
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.mutedLabel,
        ),
      ),
    );
  }
}

class _WeekRangeHeaderDelegate extends SliverPersistentHeaderDelegate {
  _WeekRangeHeaderDelegate({required this.week, required this.today});
  final DateTime week;
  final DateTime today;

  static const double _height = 28.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _WeekRangeHeader(week: week, today: today);
  }

  @override
  bool shouldRebuild(_WeekRangeHeaderDelegate old) =>
      !_sameDay(old.week, week) || !_sameDay(old.today, today);
}

/// Horizontal pill-row of weeks. Pill labels:
///   - "Предыдущая" — last week
///   - "Текущая"    — this week
///   - "Следующая"  — next week
///   - All others   — date range, e.g. "12–18 мая" or "29 апр – 5 мая"
/// The pill matching the currently-selected week paints with the V2-F
/// even/odd background of that week. Tapping a pill snaps
/// `selectedDateProvider` to that week's Monday.
class _WeekPillSelector extends ConsumerStatefulWidget {
  const _WeekPillSelector({
    required this.today,
    required this.selectedWeek,
    required this.shablonPattern,
  });
  final DateTime today;
  final DateTime selectedWeek;
  final ShablonWeekdayPattern shablonPattern;

  @override
  ConsumerState<_WeekPillSelector> createState() => _WeekPillSelectorState();
}

class _WeekPillSelectorState extends ConsumerState<_WeekPillSelector> {
  static const double _pillHeight = 38.0;

  late final ScrollController _controller;
  DateTime? _lastCenteredWeek;

  // 1.3.7: single retry guard for the cold-attach case. ScrollController
  // attaches when the Scrollable mounts; if our first post-frame callback
  // fires before that (rare, but possible behind lazy route boundaries),
  // we reschedule once more. Beyond that we give up — the math itself is
  // deterministic, no further retries are productive.
  bool _initialJumpRescheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _lastCenteredWeek = widget.selectedWeek;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToSelected());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // View-mode switch / re-mount safety net: when the route boundary or
    // an ancestor's layout settles after initState, re-aim at the current
    // week. With `itemExtent` the offset is exact from frame 1, so this is
    // an idempotent jumpTo, not a retry loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_centerOffsetFor(widget.selectedWeek));
    });
  }

  @override
  void didUpdateWidget(_WeekPillSelector old) {
    super.didUpdateWidget(old);
    if (_lastCenteredWeek == null ||
        !_sameDay(_lastCenteredWeek!, widget.selectedWeek)) {
      _lastCenteredWeek = widget.selectedWeek;
      _animateToSelected();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Cold-start path: jump (no animation) to the selected week's centre.
  /// If the controller hasn't attached yet, reschedule once more — single
  /// retry, no measurement loop.
  void _jumpToSelected() {
    if (!mounted) return;
    if (!_controller.hasClients) {
      if (_initialJumpRescheduled) return;
      _initialJumpRescheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.jumpTo(_centerOffsetFor(widget.selectedWeek));
      });
      return;
    }
    _controller.jumpTo(_centerOffsetFor(widget.selectedWeek));
  }

  /// Selection-change path (didUpdateWidget — pill tap, FAB, deep-link):
  /// smooth animate to the new centre. Touch input cancels the animation
  /// naturally because Flutter's drag gesture replaces the active scroll
  /// activity.
  void _animateToSelected() {
    if (!mounted || !_controller.hasClients) return;
    _controller.animateTo(
      _centerOffsetFor(widget.selectedWeek),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  /// Index of [week] in the pill list (0-based, today's week sits at the
  /// centre index `_kWeekListRange`).
  int _indexOf(DateTime week) {
    final todayWeek = _mondayOf(widget.today);
    final delta = week.difference(todayWeek).inDays ~/ 7;
    return delta + _kWeekListRange;
  }

  DateTime _weekAtIndex(int i) {
    final todayWeek = _mondayOf(widget.today);
    return todayWeek.add(Duration(days: (i - _kWeekListRange) * 7));
  }

  /// Exact offset that places the pill at [week] in the centre of the
  /// viewport. With `itemExtent: kWeekPillItemExtent` set on the ListView,
  /// `position.maxScrollExtent` is correct from frame 1 — no measurement
  /// loop needed.
  double _centerOffsetFor(DateTime week) {
    final index = _indexOf(week);
    final pos = _controller.position;
    return weekPillCenterOffset(
      index: index,
      itemExtent: kWeekPillItemExtent,
      viewport: pos.viewportDimension,
      minExtent: pos.minScrollExtent,
      maxExtent: pos.maxScrollExtent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final rawMode = ref.watch(dayColoringModeProvider).asData?.value ??
        DayColoringMode.auto;
    final mode = rawMode == DayColoringMode.auto
        ? (widget.shablonPattern.hasEvenOddSplit
            ? DayColoringMode.evenOdd
            : DayColoringMode.hasLessons)
        : rawMode;

    return SizedBox(
      height: _pillHeight + 16,
      child: Listener(
        onPointerSignal: (signal) {
          if (signal is PointerScrollEvent &&
              _controller.hasClients &&
              signal.scrollDelta.dy != 0) {
            final delta = signal.scrollDelta.dy;
            final target = (_controller.offset + delta).clamp(
                _controller.position.minScrollExtent,
                _controller.position.maxScrollExtent);
            _controller.jumpTo(target);
          }
        },
        child: ScrollConfiguration(
          behavior: const _DayStripScrollBehavior(),
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: _kWeekListRange * 2 + 1,
            // 1.3.7: fixed item extent. Each pill occupies exactly the same
            // slot, so the centring math is `index * extent - (viewport -
            // extent) / 2` — no measurement loop, `maxScrollExtent` is
            // correct from the first frame.
            itemExtent: kWeekPillItemExtent,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (ctx, i) {
              final weekStart = _weekAtIndex(i);
              final isSelected = _sameDay(weekStart, widget.selectedWeek);
              final todayWeek = _mondayOf(widget.today);
              final delta = weekStart.difference(todayWeek).inDays ~/ 7;
              final label = switch (delta) {
                -1 => l10n.scheduleWeekPrev,
                0 => l10n.scheduleWeekCurrent,
                1 => l10n.scheduleWeekNext,
                _ => _formatWeekRange(l10n, weekStart),
              };
              final even = _isEvenWeek(weekStart);
              final selectedFill = mode == DayColoringMode.evenOdd
                  ? (even ? c.scheduleEvenWeek : c.scheduleOddWeek)
                  : c.scheduleSelected;
              final fill = isSelected ? selectedFill : c.lessonCardFill;
              final borderColor =
                  isSelected ? selectedFill : c.lessonCardBorder;
              final textColor = isSelected
                  ? (mode == DayColoringMode.evenOdd
                      ? c.scheduleInMonthText
                      : c.scheduleSelectedText)
                  : c.lessonCardTitle;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: fill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: borderColor),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).set(weekStart);
                      // Keep the data-fetch month + strip-visible month in
                      // sync with the new week's first day so the existing
                      // grid/day-strip caches and the offline banner pick
                      // up the right month if the user later switches view.
                      final firstOfMonth =
                          DateTime(weekStart.year, weekStart.month, 1);
                      ref
                          .read(displayedMonthProvider.notifier)
                          .set(firstOfMonth);
                      ref
                          .read(stripVisibleMonthProvider.notifier)
                          .set(firstOfMonth);
                    },
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fixed pill width for the week-pill selector (1.3.7).
///
/// Sized for the longest realistic Russian labels — the cross-month range
/// "30 ноя – 6 дек" and "Предыдущая" (10 Cyrillic chars at 13px/700) —
/// with comfortable cushion: the per-pill outer Padding (4 + 4) and inner
/// Padding (10 + 10) leave ~110px of text area inside the Material body.
/// The `Text` widget inside also uses `overflow: TextOverflow.fade` so a
/// hypothetical wider label (locale change, font swap) degrades gracefully
/// rather than overflowing the slot.
///
/// Uniformity across all pills is the point — it makes
/// `position.maxScrollExtent` exact from frame 1, so centring becomes
/// pure arithmetic instead of a build-then-measure loop.
const double kWeekPillItemExtent = 138.0;

/// Pure offset math for centring a fixed-extent ListView on the [index]th
/// item. Exposed at file scope so the unit test in
/// `test/screens/week_pill_center_offset_test.dart` can exercise it
/// without mounting a Scrollable.
///
/// The formula assumes no leading padding on the ListView (the 1.3.7
/// rewrite drops the `padding: horizontal: 8`); each pill's own
/// `Padding(horizontal: 4)` provides the visual gap.
double weekPillCenterOffset({
  required int index,
  required double itemExtent,
  required double viewport,
  required double minExtent,
  required double maxExtent,
}) {
  final raw = index * itemExtent - (viewport - itemExtent) / 2;
  return raw.clamp(minExtent, maxExtent).toDouble();
}

String _formatWeekRange(AppLocalizations l10n, DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  if (monday.month == sunday.month) {
    return l10n.scheduleWeekRange(
      monday.day,
      sunday.day,
      _monthGen(l10n, monday.month),
    );
  }
  return l10n.scheduleWeekRangeCrossMonth(
    monday.day,
    _monthShort(l10n, monday.month),
    sunday.day,
    _monthShort(l10n, sunday.month),
  );
}

class _WeekDaySection extends ConsumerWidget {
  const _WeekDaySection({
    super.key,
    required this.date,
    required this.today,
    required this.entries,
    required this.notedDates,
    required this.pinnedColors,
    this.inlineNotes = true,
  });
  final DateTime date;
  final DateTime today;
  final List<RaspisanieEntry> entries;
  final Set<DateTime> notedDates;
  final Map<DateTime, List<Color>> pinnedColors;
  // 1.3.2: PC week-list layout pulls notes into the right-side column, so the
  // inline _DayNoteSection / _PinnedNotesSection rendering is opt-out.
  final bool inlineNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1.3.4 Item 3 root cause: 1.3.3's row used
                // `[Flexible(Text), Spacer, button]`. Spacer is FlexFit.tight
                // flex=1, which always claims its full flex share, so the
                // Flexible(loose flex=1) Text only got HALF the residual
                // width — even at 360px viewport with the badge absent,
                // ~150px wasn't enough for "27 апреля 2026, понедельник" so
                // ellipsis fired. Replacing Spacer with a min-sized trailing
                // cluster (Item 5) lets Expanded take ALL residual width;
                // maxLines:2 + softWrap stay as a safety net for genuinely
                // long localised strings or sub-360 viewports.
                Expanded(
                  child: Text(
                    l10n.scheduleDayHeader(
                      date.day,
                      _monthGen(l10n, date.month),
                      date.year,
                      _weekdayLong(l10n, date.weekday),
                    ),
                    maxLines: 2,
                    softWrap: true,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: c.dayHeadingText,
                    ),
                  ),
                ),
                _DayHeaderTrailing(date: date, today: today),
              ],
            ),
          ),
          _WeekDayLessons(date: date, entries: entries),
          if (inlineNotes) _DayNoteSection(date: date),
          if (inlineNotes) _PinnedNotesSection(date: date),
        ],
      ),
    );
  }
}

/// Compact "edit note" affordance pinned to the rightmost edge of every day
/// header (grid + Лента дней body, Список недели per-day section). Single
/// widget so the gesture, auth check, and styling stay in one place.
/// Caller is responsible for the auth gate (`currentUserProvider != null`)
/// because the surrounding row layout differs per view.
class _DayHeaderNoteButton extends ConsumerWidget {
  const _DayHeaderNoteButton({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final day = _dateOnly(date);
    final hasNote =
        ref.watch(dayNoteProvider(day)).asData?.value?.body.trim().isNotEmpty ??
            false;
    return SizedBox(
      height: 28,
      width: 28,
      child: IconButton(
        tooltip: hasNote ? l10n.commonEdit : l10n.scheduleNoteHint,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(
          hasNote ? Icons.edit_note : Icons.note_add_outlined,
          color: c.mutedLabel,
        ),
        onPressed: () => _openNoteDialog(context, ref, day),
      ),
    );
  }
}

/// Trailing cluster (today badge + note button) for any day header row.
/// Pinned to the rightmost edge — the Row that contains it gives the
/// header text a Flexible/Expanded so this cluster keeps its natural size
/// and stays at the end regardless of text width or which sub-elements
/// render.
class _DayHeaderTrailing extends ConsumerWidget {
  const _DayHeaderTrailing({
    required this.date,
    required this.today,
  });
  final DateTime date;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = AppPalette.of(context);
    final isToday = _sameDay(date, today);
    final canAuthorNote = ref.watch(currentUserProvider) != null;
    if (!isToday && !canAuthorNote) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c.scheduleSelected,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.scheduleTodayBadge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.scheduleSelectedText,
              ),
            ),
          ),
        if (isToday && canAuthorNote) const SizedBox(width: 8),
        if (canAuthorNote) _DayHeaderNoteButton(date: date),
      ],
    );
  }
}

/// Compact lesson list for one day inside the week-list view. Reuses
/// _SlotRow + _LessonCard so long-press expansion, "Идёт сейчас",
/// "Начнётся через" and override indicators all match grid mode.
/// Lays out as a Column rather than a SliverList because each day's
/// row count is small and the outer week-list scroll already handles
/// lazy first-frame inflation via the parent CustomScrollView.
class _WeekDayLessons extends ConsumerWidget {
  const _WeekDayLessons({required this.date, required this.entries});
  final DateTime date;
  final List<RaspisanieEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hideEmpty = ref.watch(hideEmptySlotsProvider).asData?.value ?? false;
    final noFilter = ref.watch(scheduleFiltersProvider).isEmpty;
    final currentNow = ref.watch(nowProvider);
    final plan = _buildDayPlan(
      date: date,
      entries: entries,
      hideEmpty: hideEmpty,
      noFilter: noFilter,
      currentNow: currentNow,
    );
    if (plan.noFilter) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text(
          l10n.scheduleNoFilterPicked,
          style: TextStyle(
            fontSize: 13,
            color: AppPalette.of(context).mutedLabel,
          ),
        ),
      );
    }
    if (plan.entriesEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text(
          l10n.scheduleNoLessonsOnDayShort,
          style: TextStyle(
            fontSize: 12,
            color: AppPalette.of(context).mutedLabel,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final slot in plan.visibleSlots) ...[
            if (plan.timeline != null &&
                plan.timeline!.breakBeforeOrdinal == slot.ordinal)
              const _YouAreHere(),
            _SlotRow(
              slot: slot,
              entries: plan.byOrdinal[slot.ordinal] ?? const [],
              state: plan.timeline?.stateFor(slot.ordinal) ??
                  _LessonPeriodState.idle,
              label: plan.timeline?.labelFor(l10n, slot.ordinal, plan.now),
              progress: plan.timeline?.progressFor(slot.ordinal, plan.now),
            ),
          ],
        ],
      ),
    );
  }
}
