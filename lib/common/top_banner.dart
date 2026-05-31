import 'dart:async';

import 'package:flutter/material.dart';

import '../route/go_router_provider.dart';

/// Top-anchored, auto-dismissing error banner rendered via the root
/// Overlay. Dedupes by message text: if the same message arrives while
/// still visible, its timer is reset instead of queueing a duplicate.
class TopBanner {
  static OverlayEntry? _current;
  static String? _currentMessage;
  static Timer? _timer;
  static final _animKey = GlobalKey<_TopBannerWidgetState>();

  static void showError(String message, {Duration duration = const Duration(seconds: 5)}) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    if (_current != null && _currentMessage == message) {
      _timer?.cancel();
      _timer = Timer(duration, _dismiss);
      return;
    }
    _dismissNow();
    _currentMessage = message;
    final entry = OverlayEntry(
      builder: (ctx) => _TopBannerWidget(
        key: _animKey,
        message: message,
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _dismiss);
  }

  static void _dismissNow() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
    _currentMessage = null;
  }

  static void _dismiss() {
    final state = _animKey.currentState;
    if (state == null) {
      _dismissNow();
      return;
    }
    state.runDismiss(() {
      _timer = null;
      _current?.remove();
      _current = null;
      _currentMessage = null;
    });
  }
}

class _TopBannerWidget extends StatefulWidget {
  const _TopBannerWidget({super.key, required this.message});
  final String message;

  @override
  State<_TopBannerWidget> createState() => _TopBannerWidgetState();
}

class _TopBannerWidgetState extends State<_TopBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  void runDismiss(VoidCallback onDone) {
    if (!mounted) {
      onDone();
      return;
    }
    _ctrl.reverse().whenComplete(onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                color: scheme.errorContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: TopBanner._dismiss,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 20, color: scheme.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.close,
                            size: 18, color: scheme.onErrorContainer),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
