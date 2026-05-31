import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:ncti_schedule_client/api/graphql_config.dart';

Request _stubRequest() => Request(
      operation: Operation(document: gql('query { __typename }')),
    );

void main() {
  group('TimeoutLink', () {
    test('passes through responses that arrive before the timeout', () async {
      final link = TimeoutLink(timeout: const Duration(milliseconds: 100));
      final stream = link.request(_stubRequest(), (req) async* {
        yield Response(
          data: const {'ok': true},
          response: const {},
        );
      });
      final r = await stream.first;
      expect(r.data, equals(const {'ok': true}));
    });

    test('throws TimeoutException when downstream stalls past the deadline',
        () async {
      // StreamController gives us deterministic teardown — the upstream
      // generator pattern leaves the isolate with a dangling subscription
      // that the test runner won't reap, hanging the suite forever.
      final controller = StreamController<Response>();
      addTearDown(() => controller.close());
      final link = TimeoutLink(timeout: const Duration(milliseconds: 50));
      final stream = link.request(_stubRequest(), (_) => controller.stream);
      Object? captured;
      try {
        await stream.first;
      } catch (e) {
        captured = e;
      }
      expect(captured, isA<TimeoutException>());
    });

    test('returns empty stream when no forward link is supplied', () async {
      final link = TimeoutLink();
      final stream = link.request(_stubRequest());
      expect(await stream.toList(), isEmpty);
    });

    test('uses the default 8-second deadline when no timeout is given', () {
      final link = TimeoutLink();
      expect(link.timeout, equals(const Duration(seconds: 8)));
      expect(kGraphqlRequestTimeout, equals(const Duration(seconds: 8)));
    });

    test(
        'late upstream events after the timeout fired do not double-complete '
        'the downstream completer (1.3.1 Item 6)',
        () async {
      // Reproduces the graphql 5.2.4 QueryManager pattern: a Completer
      // listens to the link's stream with NO isCompleted guard on the data
      // path. If the stream emits a TimeoutException AND a late real
      // response, the second `.complete()` call would blow up.
      final controller = StreamController<Response>();
      addTearDown(() => controller.close());
      final link = TimeoutLink(timeout: const Duration(milliseconds: 30));
      final stream = link.request(_stubRequest(), (_) => controller.stream);

      final completer = Completer<Response>();
      Object? lateError;
      stream.listen(
        (r) {
          if (!completer.isCompleted) completer.complete(r);
        },
        onError: (Object e, StackTrace _) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      // Allow the timeout to fire.
      Object? captured;
      try {
        await completer.future;
      } catch (e) {
        captured = e;
      }
      expect(captured, isA<TimeoutException>());

      // Now the upstream yields a "real" response that arrived too late.
      // The TimeoutLink should drop it on the floor — the downstream
      // controller is closed.
      runZonedGuarded(() {
        controller.add(Response(data: const {'late': true}, response: const {}));
      }, (e, _) => lateError = e);
      // Give the event loop a tick so any late dispatch surfaces.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(lateError, isNull,
          reason: 'late upstream events must not bubble out');
    });

    test(
        'a real response that arrives after the timeout deadline is silently '
        'dropped',
        () async {
      // Stronger form: even if the underlying stream eventually yields a
      // valid Response, our caller should already have observed the
      // TimeoutException — and the link should not emit a second event.
      final controller = StreamController<Response>();
      addTearDown(() => controller.close());
      final link = TimeoutLink(timeout: const Duration(milliseconds: 20));
      final stream = link.request(_stubRequest(), (_) => controller.stream);

      final events = <Object>[];
      final sub = stream.listen(
        (r) => events.add(r),
        onError: (Object e, StackTrace _) => events.add(e),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));
      controller.add(Response(data: const {'late': true}, response: const {}));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();

      expect(events, hasLength(1));
      expect(events.single, isA<TimeoutException>());
    });
  });
}
