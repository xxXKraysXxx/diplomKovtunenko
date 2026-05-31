import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Admin-only "pretend it's a different time" knob. Persisted so refreshes
/// preserve the override. Scope: schedule UI only — current-lesson highlight,
/// countdowns, today-marker, default selected date. Backend requests, auth,
/// push, and audit timestamps keep using wall-clock time.
class DebugClock extends AsyncNotifier<DateTime?> {
  static const _key = 'debug_time_override_v1';

  @override
  Future<DateTime?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> set(DateTime? value) async {
    state = AsyncValue.data(value);
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, value.toIso8601String());
    }
  }

  Future<void> clear() => set(null);
}

final debugClockProvider =
    AsyncNotifierProvider<DebugClock, DateTime?>(DebugClock.new);

/// Emits every 30 s so wall-clock consumers of [nowProvider] refresh.
final _clockTickProvider = StreamProvider<int>((ref) {
  final controller = StreamController<int>();
  var i = 0;
  controller.add(i);
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    controller.add(++i);
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Replaces `DateTime.now()` for schedule UI paths. Returns the override
/// value when set, otherwise wall-clock time refreshed by [_clockTickProvider]
/// at the same 30 s cadence the old current-minute ticker used.
final nowProvider = Provider<DateTime>((ref) {
  final override = ref.watch(debugClockProvider).asData?.value;
  if (override != null) return override;
  ref.watch(_clockTickProvider);
  return DateTime.now();
});
