import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/raspisanie_repository.dart';
import '../state/device_prefs.dart';
import '../state/schedule_filters.dart';

const kScheduleChangePushKind = 'raspisanie_changed';
const _pendingScheduleChangePrefKey = 'pending_schedule_change_v1';
const _maxMonthsPerPush = 6;

@immutable
class ScheduleChangePayload {
  const ScheduleChangePayload({
    required this.groupId,
    required this.from,
    required this.to,
  });

  final int? groupId;
  final DateTime? from;
  final DateTime? to;

  Map<String, dynamic> toJson() => {
        if (groupId != null) 'group_id': groupId,
        if (from != null) 'date_min': _isoDate(from!),
        if (to != null) 'date_max': _isoDate(to!),
      };
}

ScheduleChangePayload? parseScheduleChangePayload(Map<String, dynamic> data) {
  if (data['kind']?.toString() != kScheduleChangePushKind) return null;
  final groupId = _parseInt(data['group_id']);
  var from = _parseIsoDate(data['date_min']);
  var to = _parseIsoDate(data['date_max']);
  if (from != null && to != null && from.isAfter(to)) {
    final tmp = from;
    from = to;
    to = tmp;
  }
  return ScheduleChangePayload(groupId: groupId, from: from, to: to);
}

Future<void> recordPendingScheduleChangePayload(
    ScheduleChangePayload payload) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingScheduleChangePrefKey,
      jsonEncode(payload.toJson()),
    );
  } catch (_) {}
}

Future<ScheduleChangePayload?> takePendingScheduleChangePayload() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingScheduleChangePrefKey);
    if (raw == null) return null;
    await prefs.remove(_pendingScheduleChangePrefKey);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return parseScheduleChangePayload({
      'kind': kScheduleChangePushKind,
      ...Map<String, dynamic>.from(decoded.cast<dynamic, dynamic>()),
    });
  } catch (_) {
    return null;
  }
}

Future<void> consumePendingScheduleChange(ProviderContainer container) async {
  final pending = await takePendingScheduleChangePayload();
  if (pending == null) return;
  refreshScheduleForChange(container, pending);
}

void refreshScheduleForChange(
  ProviderContainer container,
  ScheduleChangePayload payload,
) {
  final prefs = container.read(devicePrefsProvider).asData?.value;
  if (prefs?.scheduleChanges == false) return;

  final fallbackMonth = container.read(displayedMonthProvider);
  final months = monthsTouchedByScheduleChange(
    payload,
    fallbackMonth: fallbackMonth,
  );
  if (months.isEmpty) return;

  final filters = container.read(scheduleFiltersProvider);
  final params = <MonthFilterParams>{};
  for (final month in months) {
    params.add(monthFilterParamsFor(month, filters));
    final groupId = payload.groupId;
    if (groupId != null) {
      params.add((
        month: month,
        groupId: groupId,
        teacherId: null,
        classroom: null,
      ));
    }
  }
  if (params.isEmpty) return;
  container.read(scheduleForceRefreshProvider.notifier).request(params);
  for (final p in params) {
    container.invalidate(monthRaspisanieByMonthProvider(p));
  }
}

List<DateTime> monthsTouchedByScheduleChange(
  ScheduleChangePayload payload, {
  DateTime? fallbackMonth,
}) {
  final from = payload.from;
  final to = payload.to;
  if (from == null || to == null) {
    return fallbackMonth == null ? const [] : [_firstOfMonth(fallbackMonth)];
  }
  final out = <DateTime>[];
  for (var m = _firstOfMonth(from);
      !m.isAfter(_firstOfMonth(to)) && out.length < _maxMonthsPerPush;
      m = DateTime(m.year, m.month + 1, 1)) {
    out.add(m);
  }
  return out;
}

int? _parseInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

DateTime? _parseIsoDate(Object? raw) {
  if (raw is! String) return null;
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

String _isoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
