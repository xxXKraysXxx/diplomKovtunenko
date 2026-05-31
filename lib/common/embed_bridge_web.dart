import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Tells the parent page what height the embed's Flutter content needs.
/// Dart is the authoritative height source because Flutter renders into a
/// shadow-DOM canvas whose size DOM-side scrollHeight cannot observe.
void postEmbedHeight(int h) {
  if (h <= 0) return;
  try {
    final parent = web.window.parent;
    if (parent == null) return;
    final payload = {'type': 'ncti-height', 'height': h}.jsify();
    parent.postMessage(payload, '*'.toJS);
  } catch (_) {}
}

/// Subscribes to theme changes pushed by the outer page via postMessage.
/// The outer page posts `{type: 'ncti-theme', theme: 'dark'|'light'|'system'}`
/// on its toggle flips and on iframe load. If the outer page already posted
/// before Flutter bootstrapped, the inline shim in web/index.html stashed
/// the last value at `window.__ncti_initial_theme` — replay it synchronously.
void listenEmbedTheme(void Function(String theme) onTheme) {
  try {
    final initial = _readWindowString('__ncti_initial_theme');
    if (initial != null && initial.isNotEmpty) onTheme(initial);
  } catch (_) {}
  web.window.addEventListener(
    'message',
    ((web.MessageEvent event) {
      try {
        final data = event.data.dartify();
        if (data is Map && data['type'] == 'ncti-theme') {
          final t = data['theme']?.toString();
          if (t != null) onTheme(t);
        }
      } catch (_) {}
    }).toJS,
  );
}

/// Mirrors [listenEmbedTheme] but for the UI language. The outer page posts
/// `{type: 'ncti-locale', locale: 'ru'|'en'|'system'}`; if it stashed an
/// initial value at `window.__ncti_initial_locale`, replay it synchronously.
void listenEmbedLocale(void Function(String locale) onLocale) {
  try {
    final initial = _readWindowString('__ncti_initial_locale');
    if (initial != null && initial.isNotEmpty) onLocale(initial);
  } catch (_) {}
  web.window.addEventListener(
    'message',
    ((web.MessageEvent event) {
      try {
        final data = event.data.dartify();
        if (data is Map && data['type'] == 'ncti-locale') {
          final v = data['locale']?.toString();
          if (v != null) onLocale(v);
        }
      } catch (_) {}
    }).toJS,
  );
}

String? _readWindowString(String prop) {
  final v = _getProp(web.window as JSObject, prop.toJS);
  if (v == null || v.isUndefinedOrNull) return null;
  final dart = v.dartify();
  return dart is String ? dart : null;
}

@JS('Reflect.get')
external JSAny? _getProp(JSObject target, JSString key);
