import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ScheduleFilters {
  final int? groupId;
  final int? teacherId;
  final String? classroom;

  const ScheduleFilters({this.groupId, this.teacherId, this.classroom});

  bool get isEmpty => groupId == null && teacherId == null && classroom == null;

  ScheduleFilters copyWith({
    Object? groupId = _sentinel,
    Object? teacherId = _sentinel,
    Object? classroom = _sentinel,
  }) {
    return ScheduleFilters(
      groupId: identical(groupId, _sentinel) ? this.groupId : groupId as int?,
      teacherId:
          identical(teacherId, _sentinel) ? this.teacherId : teacherId as int?,
      classroom:
          identical(classroom, _sentinel) ? this.classroom : classroom as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduleFilters &&
      other.groupId == groupId &&
      other.teacherId == teacherId &&
      other.classroom == classroom;

  @override
  int get hashCode => Object.hash(groupId, teacherId, classroom);
}

const _sentinel = Object();

/// Pref keys for the persisted schedule filter selection (1.3.2).
const String kSchedulePrefGroupId = 'schedule_filter_group_id';
const String kSchedulePrefTeacherId = 'schedule_filter_teacher_id';
const String kSchedulePrefClassroom = 'schedule_filter_classroom';

/// Synchronously-readable [SharedPreferences] handle used by
/// [ScheduleFiltersNotifier.build] to seed the filter on cold start.
///
/// Riverpod notifier [build] is synchronous, but [SharedPreferences.getInstance]
/// is `Future`-returning. The plugin caches the instance internally after
/// the first call, but exposes it only via the same async API. We mirror that
/// cache here so [main] can prime it once and the notifier can read it sync
/// from any future first-watch.
///
/// Public/visible for tests so they can inject a mock-prefs handle without
/// going through the plugin's mock channel.
SharedPreferences? scheduleFilterPrimedPrefs;

class ScheduleFiltersNotifier extends Notifier<ScheduleFilters> {
  @override
  ScheduleFilters build() {
    final prefs = scheduleFilterPrimedPrefs;
    if (prefs == null) return const ScheduleFilters();
    return ScheduleFilters(
      groupId: prefs.getInt(kSchedulePrefGroupId),
      teacherId: prefs.getInt(kSchedulePrefTeacherId),
      classroom: prefs.getString(kSchedulePrefClassroom),
    );
  }

  void setGroup(int? id) {
    state = state.copyWith(groupId: id);
    _persist();
  }

  void setTeacher(int? id) {
    state = state.copyWith(teacherId: id);
    _persist();
  }

  void setClassroom(String? name) {
    state = state.copyWith(classroom: name);
    _persist();
  }

  void clear() {
    state = const ScheduleFilters();
    _persist();
  }

  void _persist() {
    final prefs = scheduleFilterPrimedPrefs;
    if (prefs == null) return;
    final s = state;
    // Fire-and-forget — SharedPreferences setters return Futures we don't
    // need to await. Order: write/remove every key so a partial state from a
    // prior session can't bleed into the next read.
    if (s.groupId == null) {
      prefs.remove(kSchedulePrefGroupId);
    } else {
      prefs.setInt(kSchedulePrefGroupId, s.groupId!);
    }
    if (s.teacherId == null) {
      prefs.remove(kSchedulePrefTeacherId);
    } else {
      prefs.setInt(kSchedulePrefTeacherId, s.teacherId!);
    }
    if (s.classroom == null) {
      prefs.remove(kSchedulePrefClassroom);
    } else {
      prefs.setString(kSchedulePrefClassroom, s.classroom!);
    }
  }
}

final scheduleFiltersProvider =
    NotifierProvider<ScheduleFiltersNotifier, ScheduleFilters>(
  ScheduleFiltersNotifier.new,
);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

class _DateTimeNotifier extends Notifier<DateTime> {
  _DateTimeNotifier(this._initial);
  final DateTime Function() _initial;

  @override
  DateTime build() => _initial();

  void set(DateTime value) => state = value;
}

final selectedDateProvider =
    NotifierProvider<_DateTimeNotifier, DateTime>(
        () => _DateTimeNotifier(_today));

final displayedMonthProvider =
    NotifierProvider<_DateTimeNotifier, DateTime>(
        () => _DateTimeNotifier(() => _firstOfMonth(DateTime.now())));

/// Tracks the first-of-month whose cell is currently centred in the
/// day-strip carousel. Updated *only* as a side-effect of the user scrolling
/// the strip (and from taps / programmatic selection changes to keep it in
/// sync). Kept separate from [displayedMonthProvider] so scroll-driven
/// re-renders of the month label do not cascade into raspisanie / notes /
/// notifications fetches — that kept scroll from bleeding into
/// `selectedDateProvider` through shared parent rebuilds.
final stripVisibleMonthProvider =
    NotifierProvider<_DateTimeNotifier, DateTime>(
        () => _DateTimeNotifier(() => _firstOfMonth(DateTime.now())));

/// First-of-month DateTimes covering ±[stripWindowRadius] months around the
/// strip-visible month. Drives the day-strip's multi-month data fetch so that
/// scrolling past the current month finds neighbouring months already
/// populated (or in flight). Bounded to keep cold-launch fan-out in check.
const int stripWindowRadius = 2;

final stripWindowMonthsProvider = Provider<List<DateTime>>((ref) {
  final center = ref.watch(stripVisibleMonthProvider);
  return [
    for (int delta = -stripWindowRadius; delta <= stripWindowRadius; delta++)
      DateTime(center.year, center.month + delta, 1),
  ];
});

/// First day of the 6-row calendar grid for `month` — the Monday on or before
/// the first of the month.
DateTime gridStartFor(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  return first.subtract(Duration(days: first.weekday - 1));
}

/// Last day of the 6-row grid (42 days total).
DateTime gridEndFor(DateTime month) =>
    gridStartFor(month).add(const Duration(days: 41));
