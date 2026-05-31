import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall-clock instant of the most recent transition into
/// `AppLifecycleState.resumed`. Stamped from the lifecycle observer in
/// `_MyAppState`; read by [Auth.handleAuthOpFailure] so transport errors
/// fired during the brief post-resume window — when Android's connectivity
/// stack is still tearing back up after a wake — don't flash a "backend
/// unreachable" overlay before the user could even act on it.
class ResumedAt extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void mark(DateTime t) => state = t;
}

final resumedAtProvider =
    NotifierProvider<ResumedAt, DateTime?>(ResumedAt.new);
