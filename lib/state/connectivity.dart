import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the device has at least one non-"none" connectivity
/// lane. Doesn't guarantee reachability — just that the OS reports a network.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final conn = Connectivity();
  final controller = StreamController<bool>();

  bool online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  // Seed with current state.
  conn.checkConnectivity().then((r) {
    if (!controller.isClosed) controller.add(online(r));
  }).catchError((_) {
    if (!controller.isClosed) controller.add(true);
  });

  final sub = conn.onConnectivityChanged.listen((r) {
    if (!controller.isClosed) controller.add(online(r));
  }, onError: (_) {
    if (!controller.isClosed) controller.add(true);
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
