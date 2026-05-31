import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/models/news_item.dart';
import 'package:ncti_schedule_client/models/notification_item.dart';
import 'package:ncti_schedule_client/models/pinned_day_note.dart';
import 'package:ncti_schedule_client/state/notifications.dart';

/// 1.2.11 Item 2a: every read-response parser is now invoked through
/// [compute] so the JSON→Dart-object phase moves off the main isolate.
/// These tests pin the contract that lets that happen — the parser must:
/// 1. be a top-level function (compute() refuses closures and instance
///    methods),
/// 2. round-trip through [compute] without serialization errors,
/// 3. produce the exact same output as the prior in-line `.map(fromJson)
///    .toList()` form (no behavior regression).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------- NotificationItem ----------------

  Map<String, dynamic> sampleNotification({
    required int id,
    int senderUserId = 1,
    String scope = 'GLOBAL',
    String body = 'Hello',
    String? linkedDate,
    List<int> targetGroupIds = const [],
    String createdAt = '2026-04-25T10:00:00Z',
    bool isRead = false,
  }) =>
      {
        'id': id,
        'senderUserId': senderUserId,
        'sender': {
          'id': senderUserId,
          'login': 'sender$senderUserId',
          'role': 'TEACHER',
          'accentColor': '#FF0088',
        },
        'scope': scope,
        'body': body,
        'linkedDate': linkedDate,
        'targetGroupIds': targetGroupIds,
        'createdAt': createdAt,
        'isRead': isRead,
      };

  test('parseNotificationItems is top-level (compute-compatible)', () async {
    expect(
      parseNotificationItems,
      isA<List<NotificationItem> Function(List<Map<String, dynamic>>)>(),
    );
    final raw = <Map<String, dynamic>>[
      sampleNotification(id: 1, linkedDate: '2026-05-01'),
      sampleNotification(id: 2),
    ];
    final out = await compute(parseNotificationItems, raw);
    expect(out, hasLength(2));
    expect(out.first.id, 1);
    expect(out.first.linkedDate, isNotNull);
    expect(out.last.linkedDate, isNull);
  });

  test('parseNotificationItems output equals the inline map(fromJson) form',
      () {
    final raw = <Map<String, dynamic>>[
      sampleNotification(
        id: 10,
        scope: 'GROUP',
        targetGroupIds: const [1, 2],
        linkedDate: '2026-04-30',
        isRead: true,
      ),
      sampleNotification(id: 11, body: 'Reminder', isRead: false),
    ];
    final viaParser = parseNotificationItems(raw);
    final viaInline =
        raw.map(NotificationItem.fromJson).toList(growable: false);
    expect(viaParser.length, viaInline.length);
    for (var i = 0; i < viaParser.length; i++) {
      final a = viaParser[i];
      final b = viaInline[i];
      expect(a.id, b.id);
      expect(a.body, b.body);
      expect(a.scope, b.scope);
      expect(a.linkedDate, b.linkedDate);
      expect(a.targetGroupIds, b.targetGroupIds);
      expect(a.isRead, b.isRead);
      expect(a.sender.id, b.sender.id);
      expect(a.sender.role, b.sender.role);
    }
  });

  // ---------------- PinnedDayNote ----------------

  Map<String, dynamic> samplePinned({
    required int notificationId,
    String linkedDate = '2026-04-30',
    String body = 'pinned',
    String createdAt = '2026-04-29T08:00:00Z',
  }) =>
      {
        'notificationId': notificationId,
        'sender': {
          'id': 99,
          'login': 'admin',
          'role': 'ADMIN',
          'accentColor': '#00FF00',
        },
        'body': body,
        'linkedDate': linkedDate,
        'createdAt': createdAt,
      };

  test('parsePinnedDayNotes is top-level + compute-compatible', () async {
    expect(
      parsePinnedDayNotes,
      isA<List<PinnedDayNote> Function(List<Map<String, dynamic>>)>(),
    );
    final raw = <Map<String, dynamic>>[
      samplePinned(notificationId: 1),
      samplePinned(notificationId: 2, linkedDate: '2026-05-15'),
    ];
    final out = await compute(parsePinnedDayNotes, raw);
    expect(out, hasLength(2));
    expect(out.first.notificationId, 1);
    expect(out.first.sender.role.name, 'admin');
  });

  test('parsePinnedDayNotes equals the inline map(fromJson) form', () {
    final raw = <Map<String, dynamic>>[
      samplePinned(notificationId: 7, body: 'Note A'),
      samplePinned(notificationId: 8, body: 'Note B', linkedDate: '2026-05-01'),
    ];
    final viaParser = parsePinnedDayNotes(raw);
    final viaInline = raw.map(PinnedDayNote.fromJson).toList(growable: false);
    expect(viaParser.length, viaInline.length);
    for (var i = 0; i < viaParser.length; i++) {
      expect(viaParser[i].notificationId, viaInline[i].notificationId);
      expect(viaParser[i].body, viaInline[i].body);
      expect(viaParser[i].linkedDate, viaInline[i].linkedDate);
    }
  });

  // ---------------- NewsItem ----------------

  Map<String, dynamic> sampleNews({
    required int id,
    String title = 'Headline',
    String? excerpt = 'short',
    String? imageUrl,
    String sourceUrl = 'https://example.com/a',
    String? publishedAt,
    String fetchedAt = '2026-04-25T00:00:00Z',
    String? bodyText,
    String? bodyHtml,
  }) =>
      {
        'id': id,
        'title': title,
        'excerpt': excerpt,
        'imageUrl': imageUrl,
        'sourceUrl': sourceUrl,
        'publishedAt': publishedAt,
        'fetchedAt': fetchedAt,
        'bodyText': bodyText,
        'bodyHtml': bodyHtml,
      };

  test('parseNewsItems is top-level + compute-compatible', () async {
    expect(
      parseNewsItems,
      isA<List<NewsItem> Function(List<Map<String, dynamic>>)>(),
    );
    final raw = <Map<String, dynamic>>[
      sampleNews(id: 1),
      sampleNews(id: 2, bodyText: 'Full article body'),
    ];
    final out = await compute(parseNewsItems, raw);
    expect(out, hasLength(2));
    expect(out.last.bodyText, 'Full article body');
  });

  test('parseNewsItems decodes bodyHtml + null cases', () {
    final raw = <Map<String, dynamic>>[
      sampleNews(id: 1, bodyHtml: '<p>Hello <strong>world</strong></p>'),
      sampleNews(id: 2), // bodyHtml absent
      sampleNews(id: 3, bodyHtml: ''), // empty string
    ];
    final out = parseNewsItems(raw);
    expect(out, hasLength(3));
    expect(out[0].bodyHtml, '<p>Hello <strong>world</strong></p>');
    expect(out[1].bodyHtml, isNull);
    expect(out[2].bodyHtml, '');
  });

  test('NewsItem.toJson round-trips bodyHtml', () {
    final original = NewsItem.fromJson(
      sampleNews(id: 9, bodyHtml: '<p>x <a href="/a">link</a></p>'),
    );
    final asJson = original.toJson();
    expect(asJson['bodyHtml'], '<p>x <a href="/a">link</a></p>');
    final reparsed = NewsItem.fromJson(asJson.cast<String, dynamic>());
    expect(reparsed.bodyHtml, original.bodyHtml);
    expect(reparsed.id, original.id);
  });

  test('parseNewsItems equals the inline map(fromJson) form', () {
    final raw = <Map<String, dynamic>>[
      sampleNews(id: 100, title: 'A', publishedAt: '2026-04-20'),
      sampleNews(id: 101, title: 'B', excerpt: null, imageUrl: 'https://i'),
    ];
    final viaParser = parseNewsItems(raw);
    final viaInline = raw.map(NewsItem.fromJson).toList(growable: false);
    expect(viaParser.length, viaInline.length);
    for (var i = 0; i < viaParser.length; i++) {
      expect(viaParser[i].id, viaInline[i].id);
      expect(viaParser[i].title, viaInline[i].title);
      expect(viaParser[i].excerpt, viaInline[i].excerpt);
      expect(viaParser[i].imageUrl, viaInline[i].imageUrl);
      expect(viaParser[i].publishedAt, viaInline[i].publishedAt);
    }
  });
}
