import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';
import '../utils/app_utils.dart';
import 'base_source.dart';

class ZhihuSource extends ContentSource {
  final http.Client _client = http.Client();
  String? _cookies;

  static const String _baseUrl = 'https://www.zhihu.com';
  static const String _apiUrl = 'https://www.zhihu.com/api/v4';

  static const List<String> _categories = [
    '推荐', '热榜', '科技', '数码', '互联网', '游戏', '电影', '音乐',
    '体育', '财经', '法律', '医学', '心理学', '教育', '历史', '文学',
  ];

  @override
  String get platform => 'zhihu';
  @override
  String get platformLabel => '知乎';
  @override
  bool get requiresAuth => false;
  @override
  bool get isAvailable => true;

  void setCookies(String cookies) => _cookies = cookies;

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': '$_baseUrl/',
    'Accept': 'application/json, text/plain, */*',
    if (_cookies != null) 'Cookie': _cookies!,
  };

  @override
  Future<List<Recommendation>> fetchTrending({int limit = 30}) async {
    try {
      final uri = Uri.parse('$_apiUrl/topstory/hot-lists/total?limit=$limit');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['data'] as List? ?? [];
      return list.take(limit).map(_parseHotItem).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchByCategory(String category, {int limit = 30}) async {
    try {
      final uri = Uri.parse(
        '$_apiUrl/topstory/recommend?limit=$limit&action=down&after_id=-1',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['data'] as List? ?? [];
      return list.take(limit).map(_parseFeedItem).toList();
    } catch (_) {
      return search(category, limit: limit);
    }
  }

  @override
  Future<List<Recommendation>> search(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_apiUrl/search_v3?t=general&q=${Uri.encodeComponent(query)}&correction=1&offset=0&limit=$limit',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['data'] as List? ?? [];
      return list
          .where((item) => item['object'] != null)
          .take(limit)
          .map((item) => _parseSearchItem(item['object']))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchRelated(String contentId, {int limit = 10}) async {
    try {
      final uri = Uri.parse(
        '$_apiUrl/questions/$contentId/related?limit=$limit',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['data'] as List? ?? [];
      return list.take(limit).map(_parseFeedItem).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Recommendation?> getContentDetail(String contentId) async {
    try {
      final uri = Uri.parse('$_apiUrl/answers/$contentId');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return _parseAnswer(data);
    } catch (_) {
      return null;
    }
  }

  Recommendation _parseHotItem(dynamic item) {
    final target = item['target'] ?? {};
    final id = target['id']?.toString() ?? '';
    return Recommendation(
      bvid: 'zh:$id',
      contentId: id,
      itemKey: 'zhihu:$id',
      title: AppUtils.decodeHtml(target['title']?.toString() ?? ''),
      upName: '知乎热榜',
      coverUrl: (target['thumbnail'] ?? target['image_url'])?.toString() ?? '',
      contentUrl: '$_baseUrl/question/$id',
      sourcePlatform: 'zhihu',
      contentType: 'question',
      bodyText: target['excerpt']?.toString() ?? '',
      viewCount: _parseCount(item['detail_text']),
      likeCount: _parseCount(target['voteup_count']),
      commentCount: _parseCount(target['comment_count']),
      topicLabel: '热榜 #${item['detail_text']?.toString() ?? ''}',
    );
  }

  Recommendation _parseFeedItem(dynamic item) {
    final target = item['target'] ?? item;
    final type = target['type']?.toString() ?? 'answer';
    final id = target['id']?.toString() ?? '';
    final author = target['author'] ?? {};
    return Recommendation(
      bvid: 'zh:$id',
      contentId: id,
      itemKey: 'zhihu:$id',
      title: AppUtils.decodeHtml(
        target['question']?['title']?.toString() ?? target['title']?.toString() ?? '',
      ),
      upName: author['name']?.toString() ?? '',
      coverUrl: (target['thumbnail'] ?? target['image_url'])?.toString() ?? '',
      contentUrl: type == 'article'
          ? '$_baseUrl/p/$id'
          : '$_baseUrl/answer/$id',
      sourcePlatform: 'zhihu',
      contentType: type,
      bodyText: _stripHtml(target['excerpt']?.toString() ?? target['content']?.toString() ?? ''),
      publishedAt: target['created_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((target['created_time'] as num).toInt() * 1000)
              .toIso8601String()
          : '',
      likeCount: _parseCount(target['voteup_count']),
      commentCount: _parseCount(target['comment_count']),
      favoriteCount: _parseCount(target['favlist_count']),
    );
  }

  Recommendation _parseSearchItem(dynamic item) {
    final type = item['type']?.toString() ?? 'answer';
    final id = item['id']?.toString() ?? '';
    final author = item['author'] ?? {};
    return Recommendation(
      bvid: 'zh:$id',
      contentId: id,
      itemKey: 'zhihu:$id',
      title: AppUtils.decodeHtml(
        item['question']?['title']?.toString() ?? item['title']?.toString() ?? '',
      ),
      upName: author['name']?.toString() ?? '',
      coverUrl: item['thumbnail']?.toString() ?? '',
      contentUrl: type == 'article' ? '$_baseUrl/p/$id' : '$_baseUrl/answer/$id',
      sourcePlatform: 'zhihu',
      contentType: type,
      bodyText: _stripHtml(item['excerpt']?.toString() ?? ''),
      likeCount: _parseCount(item['voteup_count']),
      commentCount: _parseCount(item['comment_count']),
    );
  }

  Recommendation _parseAnswer(dynamic data) {
    final id = data['id']?.toString() ?? '';
    final author = data['author'] ?? {};
    final question = data['question'] ?? {};
    return Recommendation(
      bvid: 'zh:$id',
      contentId: id,
      itemKey: 'zhihu:$id',
      title: AppUtils.decodeHtml(question['title']?.toString() ?? ''),
      upName: author['name']?.toString() ?? '',
      coverUrl: '',
      contentUrl: '$_baseUrl/answer/$id',
      sourcePlatform: 'zhihu',
      contentType: 'answer',
      bodyText: _stripHtml(data['excerpt']?.toString() ?? data['content']?.toString() ?? ''),
      publishedAt: data['created_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((data['created_time'] as num).toInt() * 1000)
              .toIso8601String()
          : '',
      likeCount: _parseCount(data['voteup_count']),
      commentCount: _parseCount(data['comment_count']),
      favoriteCount: _parseCount(data['favlist_count']),
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  int _parseCount(dynamic value) {
    if (value is num) return value.toInt();
    final s = value?.toString() ?? '';
    if (s.isEmpty) return 0;
    if (s.contains('万')) return (double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0) * 10000 ~/ 1;
    return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  static List<String> get allCategories => _categories;
}
