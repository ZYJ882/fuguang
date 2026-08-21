import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';
import '../utils/app_utils.dart';
import 'base_source.dart';

class WebSource extends ContentSource {
  final http.Client _client = http.Client();

  static const String _bingSearch = 'https://www.bing.com/news/search';
  static const String _hnApi = 'https://hacker-news.firebaseio.com/v0';

  static const List<String> _categories = [
    '科技', '数码', '游戏', '财经', '体育', '娱乐', '教育', '健康',
    '旅游', '美食', '汽车', '房产', '军事', '历史', '科学', '设计',
  ];

  @override
  String get platform => 'web';
  @override
  String get platformLabel => '网页';
  @override
  bool get requiresAuth => false;
  @override
  bool get isAvailable => true;

  @override
  Future<List<Recommendation>> fetchTrending({int limit = 30}) async {
    try {
      final idsRes = await _client
          .get(Uri.parse('$_hnApi/topstories.json'))
          .timeout(const Duration(seconds: 10));
      if (idsRes.statusCode != 200) return [];
      final ids = (jsonDecode(idsRes.body) as List).cast<num>().take(limit).toList();
      final results = <Recommendation>[];
      for (final id in ids.take(15)) {
        try {
          final itemRes = await _client
              .get(Uri.parse('$_hnApi/item/$id.json'))
              .timeout(const Duration(seconds: 5));
          if (itemRes.statusCode == 200) {
            final item = jsonDecode(itemRes.body);
            results.add(_parseHN(item));
          }
        } catch (_) {}
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchByCategory(String category, {int limit = 30}) async {
    return search(category, limit: limit);
  }

  @override
  Future<List<Recommendation>> search(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_bingSearch?q=${Uri.encodeComponent(query)}&format=rss&count=$limit',
      );
      final res = await _client.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      return _parseRss(res.body, limit);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchRelated(String contentId, {int limit = 10}) async {
    return search(contentId, limit: limit);
  }

  @override
  Future<Recommendation?> getContentDetail(String contentId) async {
    return null;
  }

  Recommendation _parseHN(dynamic item) {
    final id = item['id']?.toString() ?? '';
    final url = item['url']?.toString() ?? 'https://news.ycombinator.com/item?id=$id';
    return Recommendation(
      bvid: 'web:hn_$id',
      contentId: id,
      itemKey: 'web:hn_$id',
      title: AppUtils.decodeHtml(item['title']?.toString() ?? ''),
      upName: item['by']?.toString() ?? 'Hacker News',
      coverUrl: '',
      contentUrl: url,
      sourcePlatform: 'web',
      contentType: 'article',
      bodyText: '',
      publishedAt: item['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((item['time'] as num).toInt() * 1000)
              .toIso8601String()
          : '',
      viewCount: (item['score'] as num?)?.toInt() ?? 0,
      commentCount: (item['descendants'] as num?)?.toInt() ?? 0,
      topicLabel: 'Hacker News',
    );
  }

  List<Recommendation> _parseRss(String xml, int limit) {
    final results = <Recommendation>[];
    final items = xml.split('<item>').skip(1).take(limit);
    for (final itemXml in items) {
      try {
        final title = _extractTag(itemXml, 'title');
        final link = _extractTag(itemXml, 'link');
        final pubDate = _extractTag(itemXml, 'pubDate');
        final description = _extractTag(itemXml, 'description');
        final source = _extractTag(itemXml, 'source');
        if (title.isEmpty) continue;
        results.add(Recommendation(
          bvid: 'web:${AppUtils.md5(link)}',
          contentId: AppUtils.md5(link),
          itemKey: 'web:${AppUtils.md5(link)}',
          title: AppUtils.decodeHtml(title),
          upName: source.isNotEmpty ? source : 'Bing News',
          coverUrl: '',
          contentUrl: link,
          sourcePlatform: 'web',
          contentType: 'article',
          bodyText: _stripHtml(description),
          publishedAt: pubDate,
          topicLabel: '网页搜索',
        ));
      } catch (_) {}
    }
    return results;
  }

  String _extractTag(String xml, String tag) {
    final match = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  static List<String> get allCategories => _categories;
}
