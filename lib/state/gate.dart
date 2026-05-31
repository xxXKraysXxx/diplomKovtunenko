import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String gateSeenPrefKey = 'gate_seen';
const String _guestChosenPrefKey = 'guest_mode_chosen';

class GateSeenNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(gateSeenPrefKey) ?? false;
  }

  /// Flips the provider value synchronously and persists in the background.
  /// The synchronous state update is what allows the router's refresh
  /// listenable to fire before the caller navigates away.
  Future<void> markSeen() async {
    state = const AsyncValue.data(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(gateSeenPrefKey, true);
    } catch (_) {
      // Plugin race on web — ignore, next app start will still read false
      // but by then the user has usually made a durable decision (login).
    }
  }
}

final gateSeenProvider =
    AsyncNotifierProvider<GateSeenNotifier, bool>(GateSeenNotifier.new);

/// Tracks whether the user has *explicitly* pressed "Продолжить как гость".
/// Distinct from [gateSeenProvider] (which just records that the onboarding
/// screen was dismissed). The auth guard allows unauthenticated access only
/// when this flag is true — not merely when gate_seen is true.
class GuestModeChosenNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestChosenPrefKey) ?? false;
  }

  Future<void> markChosen() async {
    state = const AsyncValue.data(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestChosenPrefKey, true);
    } catch (_) {}
  }

  Future<void> clear() async {
    state = const AsyncValue.data(false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestChosenPrefKey);
    } catch (_) {}
  }
}

final guestModeChosenProvider =
    AsyncNotifierProvider<GuestModeChosenNotifier, bool>(
        GuestModeChosenNotifier.new);
