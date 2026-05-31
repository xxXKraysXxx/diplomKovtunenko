/// Top-level so it can run inside [compute] (an isolate boundary refuses
/// closures and instance methods). Mirrors the raspisanie/notifications
/// parser pattern from 1.2.10/1.2.11.
List<NewsItem> parseNewsItems(List<Map<String, dynamic>> raw) =>
    raw.map(NewsItem.fromJson).toList(growable: false);

class NewsItem {
  final int id;
  final String title;
  final String? excerpt;
  final String? imageUrl;
  final String sourceUrl;
  final String? publishedAt;
  final String fetchedAt;
  final String? bodyText;
  final String? bodyHtml;

  const NewsItem({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.imageUrl,
    required this.sourceUrl,
    required this.publishedAt,
    required this.fetchedAt,
    required this.bodyText,
    required this.bodyHtml,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: j['id'] as int,
        title: (j['title'] as String?) ?? '',
        excerpt: j['excerpt'] as String?,
        imageUrl: j['imageUrl'] as String?,
        sourceUrl: (j['sourceUrl'] as String?) ?? '',
        publishedAt: j['publishedAt'] as String?,
        fetchedAt: (j['fetchedAt'] as String?) ?? '',
        bodyText: j['bodyText'] as String?,
        bodyHtml: j['bodyHtml'] as String?,
      );

  Map<String, dynamic> toJson() => {
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
}
