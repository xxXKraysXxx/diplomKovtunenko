import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/graphql_config.dart';
import '../api/queries.dart';
import '../common/cold_launch_timing.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/news_item.dart';
import 'NewsArticleScreen.dart';

String _proxyImageUrl(String url) {
  if (!kIsWeb) return url;
  final base = resolveBackendOrigin();
  return '$base/image-proxy?url=${Uri.encodeQueryComponent(url)}';
}

const _newsCacheKey = 'news_cache_v1';
const _newsCacheMaxItems = 50;

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});
  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  List<NewsItem> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCachedThenFetch();
  }

  Future<void> _loadCachedThenFetch() async {
    final cached = await _readCache();
    if (mounted && cached.isNotEmpty) {
      setState(() => _items = cached);
    }
    await _fetchFresh(silent: true);
  }

  Future<List<NewsItem>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_newsCacheKey);
      if (raw == null) return const [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeCache(List<NewsItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final capped = items.length > _newsCacheMaxItems
          ? items.sublist(0, _newsCacheMaxItems)
          : items;
      await prefs.setString(
          _newsCacheKey, jsonEncode(capped.map((i) => i.toJson()).toList()));
    } catch (_) {}
  }

  Future<List<NewsItem>> _fetch() async {
    logTiming('query.news.start');
    final client = ref.read(graphqlClientProvider);
    final r = await client.query(QueryOptions(
      document: gql(newsQuery),
      variables: const {'limit': 20},
      // Persistent news cache is the bounded prefs snapshot above; GraphQL
      // itself is memory-only now.
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    logTiming('query.news.end');
    if (r.hasException) {
      final m = r.exception!.graphqlErrors.isNotEmpty
          ? r.exception!.graphqlErrors.first.message
          : (r.exception!.linkException?.toString() ?? 'Error');
      throw m;
    }
    final raw = (r.data?['news'] as List?) ?? const [];
    if (raw.isEmpty) return const <NewsItem>[];
    final rawMaps = raw.cast<Map<String, dynamic>>().toList(growable: false);
    logTiming('compute.news.spawn');
    final parsed = await compute(parseNewsItems, rawMaps);
    logTiming('compute.news.return');
    return parsed;
  }

  Future<void> _fetchFresh({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loading = true);
    try {
      final fresh = await _fetch();
      if (!mounted) return;
      // Prepend items the cache doesn't have yet.
      final existingIds = {for (final i in _items) i.id};
      final newItems = [
        for (final i in fresh)
          if (!existingIds.contains(i.id)) i,
        ..._items,
      ];
      final merged = newItems.isEmpty ? fresh : newItems;
      setState(() {
        _items = merged;
        _loading = false;
      });
      unawaited(_writeCache(merged));
    } catch (_) {
      // Silent fail: cached items (if any) remain visible.
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(BuildContext context, NewsItem item) async {
    final uri = Uri.tryParse(item.sourceUrl);
    if (uri == null) return;
    // When the backend has a scraped body we render natively on every
    // platform. Otherwise open the source URL externally — avoids the blank
    // "offline unavailable" card users hit on mobile when an article hasn't
    // been scraped yet.
    final hasBody = (item.bodyText ?? '').trim().isNotEmpty ||
        (item.bodyHtml ?? '').trim().isNotEmpty;
    if (!hasBody) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => NewsArticleScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          l10n.newsTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchFresh(silent: false),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(child: Text(l10n.newsEmpty)),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _NewsCard(
        item: _items[i],
        onTap: () => _open(context, _items[i]),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onTap});
  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (item.excerpt != null && item.excerpt!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.excerpt!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (item.publishedAt != null &&
                        item.publishedAt!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(item.publishedAt!),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _proxyImageUrl(item.imageUrl!),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 96,
                      height: 96,
                      color: scheme.surfaceContainerHighest,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 96,
                      height: 96,
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Renders ISO yyyy-mm-dd as "DD.MM.YYYY" for display; passes anything
// else through unchanged (the scraper falls back to the raw page string
// when it can't parse the date).
String _formatDate(String s) {
  if (s.length == 10 && s[4] == '-' && s[7] == '-') {
    return '${s.substring(8)}.${s.substring(5, 7)}.${s.substring(0, 4)}';
  }
  return s;
}
