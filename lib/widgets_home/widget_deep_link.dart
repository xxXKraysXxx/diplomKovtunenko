import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../route/go_router_provider.dart';
import '../state/schedule_filters.dart';

/// Registers the warm-click handler and, on the first frame, processes the
/// URI that was used to cold-launch the app (if any). URIs use the form
/// `ncti://widget/schedule?date=YYYY-MM-DD`.
void installWidgetDeepLinkHandler(ProviderContainer container) {
  if (kIsWeb) return;

  HomeWidget.widgetClicked.listen((uri) {
    _handleUri(container, uri);
  });

  unawaited(HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
    _handleUri(container, uri);
  }));
}

void _handleUri(ProviderContainer container, Uri? uri) {
  if (uri == null) return;

  // Optional date hop: cubes in the week widget carry a `date=YYYY-MM-DD`
  // hint so the schedule lands on the day the user tapped. Without it (the
  // plain CTA path) we still want to navigate, so the empty-filter user gets
  // to the picker instead of being stuck on whatever screen launched.
  final dateStr = uri.queryParameters['date'];
  if (dateStr != null) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) {
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      container.read(selectedDateProvider.notifier).set(day);
      final firstOfMonth = DateTime(day.year, day.month, 1);
      container.read(displayedMonthProvider.notifier).set(firstOfMonth);
      container.read(stripVisibleMonthProvider.notifier).set(firstOfMonth);
    }
  }

  // Navigate after the Riverpod writes so the screen picks up the new date
  // on its first build.
  scheduleMicrotask(() {
    try {
      final router = container.read(routerProvider);
      if (router.routerDelegate.currentConfiguration.uri.path !=
          '/schedule') {
        router.go('/schedule');
      }
    } catch (_) {
      // Router not ready yet — the selectedDateProvider write is enough.
    }
  });
}
