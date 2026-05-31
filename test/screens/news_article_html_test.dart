import 'package:flutter_test/flutter_test.dart';

import 'package:ncti_schedule_client/screens/NewsArticleScreen.dart';

void main() {
  group('stripLeadingPreviewImg (URL-aware, 1.3.8 Item 2)', () {
    // Production failure mode: "Спасфест" body opens with a stray title-link
    // and date span, then `<p><a href="<preview-path>"><img/></a>caption…</p>`.
    // The original 1.3.1 positional regex couldn't reach past the title link,
    // and even if it could, it required the <p> to contain ONLY the image.
    // URL-aware matching strips the duplicate anchor regardless of position.
    test('drops the production "Спасфест" duplicate (anchor-wrapped)', () {
      const banner = 'http://ncti.ru/images/stories/news/2211_1.png';
      const body =
          '\n      \n     \n\n\t\t\n\t\t\t\t<a href="/novosti/...">Title</a>'
          '\n\n\t\t24.04.26\t\n\n'
          '<p><a href="/images/stories/news/2211_1.png">'
          '<img alt="" src="/news-image/96d23721/></a>'
          'Оказание первой помощи — важный навык в современном мире!</p>';
      final out = stripLeadingPreviewImg(body, banner);
      expect(out.contains('/news-image/96d23721'), isFalse,
          reason: 'the duplicate <img> must be gone');
      expect(out.contains('Оказание первой помощи'), isTrue,
          reason: 'the lead caption text must survive — it is article content');
      expect(out.contains('<a href="/novosti/...">Title</a>'), isTrue,
          reason: "the unrelated title-link <a> must NOT be touched");
    });

    test('drops <a href><img></a> when href path matches the banner', () {
      final out = stripLeadingPreviewImg(
        '<p><a href="/images/stories/news/x.png">'
        '<img src="/news-image/abc"/></a>caption</p>',
        'http://ncti.ru/images/stories/news/x.png',
      );
      expect(out, '<p>caption</p>');
    });

    test('matches absolute hrefs against absolute banner URLs', () {
      // Old (pre-rewrite) articles use absolute hrefs and absolute srcs both
      // pointing at ncti.ru — same path component, so dedup still fires.
      final out = stripLeadingPreviewImg(
        '<p><a href="http://ncti.ru/images/stories/news/2205_1.png" rel="nofollow">'
        '<img alt="" src="http://ncti.ru/images/stories/news/2205_1.png" width="250"/>'
        '</a>Это было вчера.</p>',
        'http://ncti.ru/images/stories/news/2205_1.png',
      );
      expect(out.contains('<img'), isFalse);
      expect(out.contains('Это было вчера'), isTrue);
    });

    test('keeps body when first <a><img></a> href does NOT match banner', () {
      // First image is a gallery photo, NOT the preview. Don't strip it
      // just because it happens to be the first one — that would erase a
      // legitimate article image.
      const banner = 'http://ncti.ru/images/stories/news/preview.png';
      const body =
          '<p><a href="/images/stories/news/gallery_a.jpg">'
          '<img src="/news-image/aaa"/></a>'
          '<a href="/images/stories/news/gallery_b.jpg">'
          '<img src="/news-image/bbb"/></a></p>';
      expect(stripLeadingPreviewImg(body, banner), body);
    });

    test('falls back to bare <img src> matching when no <a> wrapper', () {
      final out = stripLeadingPreviewImg(
        '<img src="https://h/images/stories/news/x.png"/>'
        '<p>Body text.</p>',
        'http://ncti.ru/images/stories/news/x.png',
      );
      expect(out, '<p>Body text.</p>');
    });

    test('no-op when bannerImageUrl is null or empty', () {
      const body =
          '<p><a href="/images/stories/news/x.png"><img src="/y"/></a></p>';
      expect(stripLeadingPreviewImg(body, null), body);
      expect(stripLeadingPreviewImg(body, ''), body);
    });

    test('keeps later imgs after the first matched <a><img></a>', () {
      // The duplicate is stripped; subsequent gallery images survive.
      final out = stripLeadingPreviewImg(
        '<p><a href="/images/stories/news/preview.png">'
        '<img src="/news-image/preview-sha"/></a>caption</p>'
        '<p><a href="/images/stories/news/gallery.jpg">'
        '<img src="/news-image/gallery-sha"/></a></p>',
        'http://ncti.ru/images/stories/news/preview.png',
      );
      expect(out.contains('preview-sha'), isFalse);
      expect(out.contains('gallery-sha'), isTrue);
    });

    test('handles single-quoted href attribute', () {
      final out = stripLeadingPreviewImg(
        "<a href='/images/stories/news/x.png'><img src='/news-image/abc'/></a>",
        'http://ncti.ru/images/stories/news/x.png',
      );
      expect(out, '');
    });
  });

  group('stripAnchorsAroundImages', () {
    test('removes <a href> wrapping a bare <img>', () {
      final out = stripAnchorsAroundImages(
        '<a href="https://x/y"><img src="/news-image/a"/></a>',
      );
      expect(out, '<img src="/news-image/a"/>');
    });

    test('keeps anchors that wrap text', () {
      const input = '<a href="https://x">label</a>';
      expect(stripAnchorsAroundImages(input), input);
    });

    test('preserves ordering of multiple wrapped images', () {
      final out = stripAnchorsAroundImages(
        '<a href="x"><img src="/a"/></a> middle '
        '<a href="y"><img src="/b"/></a>',
      );
      expect(out.contains('<img src="/a"/>'), isTrue);
      expect(out.contains('<img src="/b"/>'), isTrue);
      expect(out.contains('<a href'), isFalse);
    });
  });

  group('absolutiseNewsImageURLs', () {
    test('rewrites double-quoted srcs', () {
      final out = absolutiseNewsImageURLs(
        '<p><img src="/news-image/abc"/></p>',
        'https://schedule-ncti.thehexus.ru',
      );
      expect(
        out,
        '<p><img src="https://schedule-ncti.thehexus.ru/news-image/abc"/></p>',
      );
    });

    test('rewrites single-quoted srcs', () {
      final out = absolutiseNewsImageURLs(
        "<img src='/news-image/xyz'>",
        'https://example.com',
      );
      expect(out, "<img src='https://example.com/news-image/xyz'>");
    });

    test('leaves absolute srcs alone', () {
      final input = '<img src="https://other.example/x.png">';
      expect(
        absolutiseNewsImageURLs(input, 'https://schedule-ncti.thehexus.ru'),
        input,
      );
    });

    test('leaves text containing /news-image/ outside src= alone', () {
      // String must appear inside src=" / src=' to be rewritten. A bare
      // path in body text should pass through unchanged.
      final input = '<p>see /news-image/abc for details</p>';
      expect(absolutiseNewsImageURLs(input, 'https://h'), input);
    });

    test('rewrites multiple imgs in one document', () {
      final out = absolutiseNewsImageURLs(
        '<p><img src="/news-image/a"/></p>'
        '<p>text <img src="/news-image/b" alt="x"/></p>',
        'https://h',
      );
      expect(out.contains('https://h/news-image/a'), isTrue);
      expect(out.contains('https://h/news-image/b'), isTrue);
    });
  });
}
