import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'token_store.dart';

/// Hard ceiling on every GraphQL request so a stalled TCP connection (DNS
/// race after wake-from-sleep, half-open socket, slow-loris server) can't
/// freeze the UI. The 1.2.3 timeout only wrapped `Auth.build()`; this lifts
/// it to the link layer so every query/mutation/subscription gets the same
/// guard for free.
const Duration kGraphqlRequestTimeout = Duration(seconds: 8);

/// Aborts each request after [timeout] elapses by surfacing
/// [TimeoutException] inside a `LinkException`. graphql_flutter wraps that
/// into `OperationException.linkException`, so existing
/// `looksLikeBackendUnreachable` callers route the error through the
/// "backend unreachable" overlay automatically.
///
/// **1.3.1 Item 6 — single-shot semantics.** Earlier the link used the bare
/// `Stream.timeout` operator, which keeps listening to the upstream after
/// firing the timeout error. graphql 5.2.4's `QueryManager._executeOnNetwork`
/// listens with `responseStream.listen(completer.complete, ...)` — note the
/// data-side callback has *no* `isCompleted` guard. So if HttpLink's
/// `async*` generator finally yielded a real response after we already
/// completed the completer with the TimeoutException, the late `complete()`
/// blew up the engine with "Bad state: Future already completed". We saw
/// 8 of those in 4 seconds on the 1.3.0 logcat trace.
///
/// Fix: emit at most one event (whichever wins — real response or
/// timeout), then close the stream and cancel the upstream subscription.
/// Late HttpLink yields fall into a closed stream and are silently dropped,
/// so QueryManager's completer is only ever called once.
class TimeoutLink extends Link {
  TimeoutLink({this.timeout = kGraphqlRequestTimeout});
  final Duration timeout;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    if (forward == null) {
      return const Stream<Response>.empty();
    }
    final upstream = forward(request);
    return _buildSingleShotTimeoutStream(upstream, timeout);
  }
}

Stream<Response> _buildSingleShotTimeoutStream(
    Stream<Response> upstream, Duration timeout) {
  late StreamController<Response> controller;
  StreamSubscription<Response>? sub;
  Timer? timer;
  bool emitted = false;

  void closeAll() {
    timer?.cancel();
    timer = null;
    final s = sub;
    sub = null;
    s?.cancel();
    if (!controller.isClosed) controller.close();
  }

  void emitOnce(void Function() body) {
    if (emitted || controller.isClosed) return;
    emitted = true;
    body();
    closeAll();
  }

  controller = StreamController<Response>(
    onCancel: () {
      timer?.cancel();
      timer = null;
      final s = sub;
      sub = null;
      return s?.cancel();
    },
  );
  controller.onListen = () {
    timer = Timer(timeout, () {
      emitOnce(() => controller.addError(
          TimeoutException('GraphQL request exceeded $timeout', timeout),
          StackTrace.current));
    });
    sub = upstream.listen(
      (event) => emitOnce(() => controller.add(event)),
      onError: (Object e, StackTrace s) =>
          emitOnce(() => controller.addError(e, s)),
      onDone: () {
        // Upstream closed without emitting — leave the timer to either fire
        // a TimeoutException or, if it has already fired, become a no-op.
        if (emitted) return;
      },
      cancelOnError: false,
    );
  };
  return controller.stream;
}

const _apiHost = String.fromEnvironment('API_HOST');
const _apiUrl = String.fromEnvironment('API_URL');

const _backendPort = 9997;

/// Fallback production endpoint used on release mobile builds when no
/// `API_URL` / `API_HOST` dart-define is provided. Baked-URL builds for
/// earlier releases pointed at the old home-PC Apache reverse proxy; that
/// proxy now returns 503 because the backend has moved to the VPS. This
/// constant removes the footgun — forgetting `--dart-define` no longer
/// ships a dead endpoint.
const _mobileProductionGraphqlUrl = 'https://schedule-ncti.thehexus.ru/graphql';
const _mobileProductionOrigin = 'https://schedule-ncti.thehexus.ru';

/// Resolves the origin (scheme + host[:port]) of the backend.
/// Web uses HTTPS via reverse proxy; native goes direct to :9997.
///
/// Priority: explicit API_URL (strip path) > API_HOST > same-origin on web >
/// localhost fallback on native.
/// The API_URL path gets stripped so callers can append their own
/// ("/image-proxy", "/graphql", …).
String resolveBackendOrigin({
  String? apiHostOverride,
  String? apiUrlOverride,
  bool? isWebOverride,
  String? webOriginOverride,
}) {
  final explicitUrl = apiUrlOverride ?? _apiUrl;
  if (explicitUrl.isNotEmpty) {
    final parsed = Uri.tryParse(explicitUrl);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      final port = parsed.hasPort ? ':${parsed.port}' : '';
      return '${parsed.scheme}://${parsed.host}$port';
    }
  }
  final host = apiHostOverride ?? _apiHost;
  final web = isWebOverride ?? kIsWeb;
  if (host.isNotEmpty) {
    return web ? 'https://$host' : 'http://$host:$_backendPort';
  }
  if (web) {
    // Same-origin: the bundle is served from the backend's reverse proxy,
    // so requests go back to whatever origin the page was loaded from.
    // Dev caveat: `flutter run -d chrome` points this at localhost:<port>,
    // which has no backend — pass --dart-define=API_URL=... for dev web.
    return webOriginOverride ?? Uri.base.origin;
  }
  final debug = kDebugMode;
  if (debug) return 'http://localhost:$_backendPort';
  return _mobileProductionOrigin;
}

/// Resolves the GraphQL endpoint URL.
///
/// [apiHostOverride] and [debugModeOverride] exist for unit testing only;
/// production code should use [graphqlEndpointProvider].
String resolveGraphqlUrl({
  String? apiHostOverride,
  String? apiUrlOverride,
  bool? debugModeOverride,
  bool? isWebOverride,
  String? webOriginOverride,
}) {
  final explicitUrl = apiUrlOverride ?? _apiUrl;
  if (explicitUrl.isNotEmpty) return explicitUrl;
  final host = apiHostOverride ?? _apiHost;
  final debug = debugModeOverride ?? kDebugMode;
  final web = isWebOverride ?? kIsWeb;
  if (host.isNotEmpty) {
    return web ? 'https://$host/graphql' : 'http://$host:$_backendPort/graphql';
  }
  if (web) {
    // Same-origin: the bundle is served from the backend's reverse proxy,
    // so `/graphql` hits whatever origin the page was loaded from.
    // Dev caveat: `flutter run -d chrome` points this at localhost:<port>
    // and the backend likely isn't there — pass --dart-define=API_URL=...
    // (or API_HOST=...) for dev web.
    return '${webOriginOverride ?? Uri.base.origin}/graphql';
  }
  if (!debug) {
    // Release mobile with no defines: fall through to the VPS default
    // rather than crashing. Explicit --dart-define=API_URL=... still wins.
    return _mobileProductionGraphqlUrl;
  }
  // Debug-mode fallbacks for local dev iteration:
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:$_backendPort/graphql';
  }
  return 'http://localhost:$_backendPort/graphql';
}

final graphqlEndpointProvider = Provider<String>((_) => resolveGraphqlUrl());

/// Bumps on login/logout so the client rebuilds and the AuthLink
/// re-reads the in-memory token.
class AuthEpoch extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state = state + 1;
}

final authEpochProvider = NotifierProvider<AuthEpoch, int>(AuthEpoch.new);

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  ref.watch(authEpochProvider);
  final endpoint = ref.watch(graphqlEndpointProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  final authLink = AuthLink(getToken: () async {
    final t = tokenStore.cached ?? await tokenStore.load();
    if (t == null || t.isEmpty) return null;
    return 'Bearer $t';
  });
  final http = HttpLink(endpoint);
  // Order matters: AuthLink must run first so the bearer header is attached,
  // then TimeoutLink wraps the actual transport so the deadline applies to
  // the network leg only (not to header build).
  final link = Link.from([authLink, TimeoutLink(), http]);
  // Keep graphql_flutter's normalized cache in memory only. A persistent
  // HiveStore opens eagerly and scales cold-start latency with every cached
  // GraphQL entity, so disk caching now lives in small feature-specific
  // stores instead (schedule has its own bounded cache).
  return GraphQLClient(
    link: link,
    cache: GraphQLCache(store: InMemoryStore()),
    defaultPolicies: DefaultPolicies(
      query: Policies(fetch: FetchPolicy.networkOnly),
      watchQuery: Policies(fetch: FetchPolicy.networkOnly),
    ),
  );
});
