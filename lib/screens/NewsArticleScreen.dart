import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/graphql_config.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/news_item.dart';

class NewsArticleScreen extends StatelessWidget {
  const NewsArticleScreen({super.key, required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final html = (item.bodyHtml ?? '').trim();
    final text = (item.bodyText ?? '').trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.title,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          IconButton(
            tooltip: l10n.newsOpenInBrowser,
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _openExternal(item.sourceUrl),
          ),
        ],
      ),
      body: html.isNotEmpty
          ? _HtmlArticle(item: item, html: html)
          : (text.isNotEmpty
              ? _PlaintextArticle(item: item, body: text)
              : _MissingBodyFallback(url: item.sourceUrl)),
    );
  }
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.url, required this.scheme});
  final String url;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 560,
          maxHeight: 360,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => _openImageLightbox(context, url),
            child: CachedNetworkImage(
              imageUrl: _proxyImageUrl(url),
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                height: 200,
                color: scheme.surfaceContainerHighest,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the server-sanitised bodyHtml. The scraper rewrites every
/// `<img src>` to `/news-image/<sha256>` (path-relative); we absolutise it
/// against the backend origin before handing the HTML to flutter_html so
/// the widget can fetch the bytes.
class _HtmlArticle extends StatelessWidget {
  const _HtmlArticle({required this.item, required this.html});
  final NewsItem item;
  final String html;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final imageUrl = item.imageUrl;
    final hasBanner = imageUrl != null && imageUrl.isNotEmpty;
    // 1.3.1 Item 4c: server stores the article preview AND a duplicate of the
    // same image as the first body element. Strip the leading <img> when a
    // banner is rendered so the user sees the preview once, not twice. Pure
    // helper at the top of this file so unit tests can pin the parse rules.
    // 1.3.1 Item 4b: drop wrapping `<a href>` from images so flutter_html's
    // anchor tap doesn't fire on image clicks (it called launchUrl, which on
    // the web reloaded the app inside a new tab).
    var prepared = _absolutiseNewsImageURLs(html);
    // 1.3.8 Item 2: dedup the preview image FIRST, while the original
    // ncti.ru `<a href>` wrapping each `<img>` is still intact — that's the
    // only field that matches the banner's `imageUrl` (the `<img src>` itself
    // has been server-rewritten to `/news-image/<sha>` and isn't directly
    // comparable). stripAnchorsAroundImages then drops the remaining
    // wrappers as before.
    if (hasBanner) prepared = stripLeadingPreviewImg(prepared, imageUrl);
    prepared = stripAnchorsAroundImages(prepared);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (hasBanner) ...[
          _BannerImage(url: imageUrl, scheme: scheme),
          const SizedBox(height: 16),
        ],
        Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        if (item.publishedAt != null && item.publishedAt!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _formatDate(item.publishedAt!),
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SelectionArea(
          child: Html(
            data: prepared,
            style: {
              'body': Style(
                fontSize: FontSize(15),
                lineHeight: const LineHeight(1.5),
                color: scheme.onSurface,
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'p': Style(
                margin: Margins.only(bottom: 12),
              ),
              'a': Style(
                color: scheme.primary,
                textDecoration: TextDecoration.underline,
              ),
            },
            extensions: [
              // Custom <img> handler — flutter_html's built-in passes
              // Style.width.value (a raw `100`, *not* 100% in pixels) straight
              // into Image.network's width arg, so the v3.0.0 builtin renders
              // every body image at 100px regardless of viewport. Roll our
              // own that asks MediaQuery for the available width and caps on
              // wide PC viewports.
              _NewsImageExtension(
                onImageTap: (src) => _openImageLightbox(context, src),
              ),
            ],
            onLinkTap: (url, _, __) {
              if (url == null || url.isEmpty) return;
              _openExternal(url);
            },
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openExternal(item.sourceUrl),
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: Text(l10n.newsOpenOnSource),
        ),
      ],
    );
  }
}

class _PlaintextArticle extends StatelessWidget {
  const _PlaintextArticle({required this.item, required this.body});
  final NewsItem item;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final paragraphs = body.split(RegExp(r'\n{2,}'));
    final imageUrl = item.imageUrl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          _BannerImage(url: imageUrl, scheme: scheme),
          const SizedBox(height: 16),
        ],
        Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        if (item.publishedAt != null && item.publishedAt!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _formatDate(item.publishedAt!),
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final p in paragraphs) ...[
          SelectableText(
            p,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openExternal(item.sourceUrl),
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: Text(l10n.newsOpenOnSource),
        ),
      ],
    );
  }
}

class _MissingBodyFallback extends StatelessWidget {
  const _MissingBodyFallback({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              l10n.newsOfflineUnavailable,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openExternal(url),
              icon: const Icon(Icons.open_in_browser),
              label: Text(l10n.newsOpenInBrowser),
            ),
          ],
        ),
      ),
    );
  }
}

String _proxyImageUrl(String url) {
  if (!kIsWeb) return url;
  final base = resolveBackendOrigin();
  return '$base/image-proxy?url=${Uri.encodeQueryComponent(url)}';
}

/// Rewrites every `src="/news-image/..."` to an absolute URL pointing at the
/// backend origin so flutter_html's NetworkImage can actually fetch the
/// bytes. Top-level + pure so it's covered by the parser unit tests.
String absolutiseNewsImageURLs(String html, String origin) {
  return html
      .replaceAll('src="/news-image/', 'src="$origin/news-image/')
      .replaceAll("src='/news-image/", "src='$origin/news-image/");
}

String _absolutiseNewsImageURLs(String html) {
  return absolutiseNewsImageURLs(html, resolveBackendOrigin());
}

/// Strips the article-preview duplicate from [html] when [bannerImageUrl] is
/// going to be rendered separately above the article. The ncti.ru CMS opens
/// every body with `<a href="<original-image-path>"><img/></a>caption text…`
/// — the `<img src>` has been server-rewritten to `/news-image/<sha>`, but
/// the wrapping `<a href>` retains the original path, which matches the
/// banner's `imageUrl`. We use that anchor as the dedup signal.
///
/// 1.3.1's positional rule (drop the leading `<p><img></p>` or bare `<img>`)
/// missed the production case because the body actually starts with a stray
/// title-link + date span before the first image, AND because the `<p>`
/// hosting the preview image also contains the article's lead caption. URL-
/// aware matching works regardless of position and never strips an image
/// that doesn't share a path with the banner.
String stripLeadingPreviewImg(String html, String? bannerImageUrl) {
  if (bannerImageUrl == null || bannerImageUrl.isEmpty) return html;
  String bannerPath;
  try {
    bannerPath = Uri.parse(bannerImageUrl).path;
  } catch (_) {
    return html;
  }
  if (bannerPath.isEmpty || bannerPath == '/') return html;

  // Pattern A: <a href="X"><img/></a>. ncti.ru wraps the duplicate in an
  // anchor linking to the original (unrewritten) preview path. Strip the
  // FIRST such anchor whose href shares the banner's path; if the first
  // image-anchor's href doesn't match, the article doesn't open with the
  // preview duplicate, so leave it alone (don't scan further — that would
  // risk eating a legitimate gallery image).
  final wrappedPattern = RegExp(
    '''<a\\b[^>]*\\shref=["']([^"']+)["'][^>]*>\\s*<img\\b[^>]*?/?\\s*>\\s*</a>''',
    caseSensitive: false,
  );
  final firstWrapped = wrappedPattern.firstMatch(html);
  if (firstWrapped != null) {
    final href = firstWrapped.group(1) ?? '';
    String hrefPath;
    try {
      hrefPath = Uri.parse(href).path;
    } catch (_) {
      hrefPath = href;
    }
    if (hrefPath == bannerPath) {
      return html.replaceRange(firstWrapped.start, firstWrapped.end, '');
    }
    return html;
  }

  // Pattern B: bare <img src="X"> (no anchor). Match the FIRST <img> if its
  // src path equals the banner path (rare on ncti.ru, but covers articles
  // whose anchor was already stripped upstream).
  final imgPattern = RegExp(
    '''<img\\b[^>]*\\ssrc=["']([^"']+)["'][^>]*?/?\\s*>''',
    caseSensitive: false,
  );
  final firstImg = imgPattern.firstMatch(html);
  if (firstImg != null) {
    final src = firstImg.group(1) ?? '';
    String srcPath;
    try {
      srcPath = Uri.parse(src).path;
    } catch (_) {
      srcPath = src;
    }
    if (srcPath == bannerPath) {
      return html.replaceRange(firstImg.start, firstImg.end, '');
    }
  }

  return html;
}

/// Removes wrapping `<a>` around `<img>` so flutter_html's anchor tap path
/// doesn't fire on image clicks. Without this, the bluemonday-sanitised
/// bodyHtml occasionally still contains `<a href="…"><img …></a>` (the CMS
/// links the preview image back to itself); on web that calls launchUrl
/// with `LaunchMode.externalApplication`, which the embedded webview
/// interprets as "navigate to top-level URL", reloading the app shell.
String stripAnchorsAroundImages(String html) {
  final pattern = RegExp(
    r'<a\b[^>]*>\s*(<img\b[^>]*?/?\s*>)\s*</a>',
    caseSensitive: false,
  );
  return html.replaceAllMapped(pattern, (m) => m.group(1) ?? '');
}

void _openImageLightbox(BuildContext context, String src) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (_, __, ___) => _ImageLightbox(src: src),
    ),
  );
}

class _ImageLightbox extends StatelessWidget {
  const _ImageLightbox({required this.src});
  final String src;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      _proxyImageUrl(src),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom `<img>` rendering that asks MediaQuery for the available article
/// width and renders the image at that size (or its native size, whichever
/// is smaller) — matches CSS `max-width: 100%; height: auto`. Wraps the
/// image in a tap handler so a user click opens the lightbox.
class _NewsImageExtension extends HtmlExtension {
  const _NewsImageExtension({required this.onImageTap});
  final void Function(String src) onImageTap;

  static const double _articleHorizontalPad = 32; // ListView 16+16
  static const double _wideViewportImageCap = 720;

  @override
  Set<String> get supportedTags => const {'img'};

  @override
  bool matches(ExtensionContext context) => context.elementName == 'img';

  @override
  InlineSpan build(ExtensionContext context) {
    final src = (context.attributes['src'] ?? '').trim();
    if (src.isEmpty) return const TextSpan(text: '');
    final alt = context.attributes['alt'];
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Builder(
        builder: (ctx) {
          final viewportWidth = MediaQuery.of(ctx).size.width;
          final available = (viewportWidth - _articleHorizontalPad)
              .clamp(120.0, _wideViewportImageCap);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: GestureDetector(
              onTap: () => onImageTap(src),
              child: SizedBox(
                width: available,
                child: Image.network(
                  src,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(alt ?? ''),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _openExternal(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

String _formatDate(String s) {
  if (s.length == 10 && s[4] == '-' && s[7] == '-') {
    return '${s.substring(8)}.${s.substring(5, 7)}.${s.substring(0, 4)}';
  }
  return s;
}
