/// Browser bridge for the /embed route: reports content height to the
/// parent page and receives theme changes. Conditional export keeps
/// non-web builds from pulling in `dart:html`.
export 'embed_bridge_stub.dart'
    if (dart.library.js_interop) 'embed_bridge_web.dart';
