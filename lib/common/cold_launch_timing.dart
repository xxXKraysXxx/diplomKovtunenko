// 1.3.0 cold-launch diagnostic instrumentation.
//
// Always-on (no behind-flag): 1.3.0 ships as a diagnostic build so the user
// can install once and capture timing logs via `adb logcat -s flutter`.
// Each call emits `[timing] <label> elapsed=Xms` — the `[timing]` prefix is
// the grep target.
//
// 1.3.1 Item 5: switched the primary sink from `developer.log` to
// `debugPrint` because `developer.log` is consumed by DevTools / vmService
// only — it does NOT propagate to stdout, so `adb logcat -s flutter`
// captured nothing on a release-mode 1.3.0 APK. `debugPrint` calls `print`
// (the Flutter platform channel routes that to logcat under the `flutter`
// tag), so logcat now sees the lines we expect. `developer.Timeline` is
// dual-emitted alongside so DevTools timeline events still work for a
// future profiling pass.
//
// `_coldStart` is module-private; the first import of this file kicks the
// stopwatch. Call sites do not need to manage start state. Once the user
// has the cold-launch trace they need, this whole module can be gutted in
// a follow-up release.

import 'package:flutter/foundation.dart' show debugPrint;

import 'dart:developer' as developer;

final Stopwatch _coldStart = Stopwatch()..start();

void logTiming(String label) {
  final ms = _coldStart.elapsedMilliseconds;
  // Primary sink — debugPrint goes through Flutter's platform-channel print
  // hook on Android, which surfaces in logcat under the `flutter` tag.
  // Release builds keep debugPrint enabled (it's only stripped in `flutter
  // run --release` if explicitly muted), so the diagnostic build captures
  // them cold-launch.
  debugPrint('[timing] $label elapsed=${ms}ms');
  // Secondary — DevTools / vmService consumers (timeline view, profile
  // mode) keep working. No-op for the logcat path.
  developer.Timeline.instantSync('timing.$label',
      arguments: {'elapsed_ms': ms});
}

int coldLaunchElapsedMs() => _coldStart.elapsedMilliseconds;
