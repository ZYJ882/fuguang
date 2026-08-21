import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';
import '../utils/app_utils.dart';
import 'base_source.dart';

class DouyinSource extends ContentSource {
  final http.Client _client = http.Client();
  String? _cookies;

  static const String _baseUrl = 'https://www.douyin.com';
  static const String _apiUrl = 'https://www.douyin.com/aweme/v1/web';

  static const List<String> _categories = [
    '推荐', '热点', '游戏', '音乐', '美食', '旅行', '体育', '时尚',
    '美妆', '萌宠', '舞蹈', '搞笑', '知识', '科技', '汽车', '影视',
  ];

  @override
  String get platform => 'douyin';
  @override
  String get platformLabel => '抖音';
  @override
  bool get requiresAuth => true;
  @override
  bool get isAvailable => _cookies != null && _cookies!.isNotEmpty;

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
    if (!isAvailable) return [];
    try {
      final uri = Uri.parse('$_apiUrl/hot/search/?device_platform=webapp&aid=6383');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['data']['word_list'] as List? ?? [];
      return list.take(limit).map(_parseHotItem).toList();
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
    if (!isAvailable) return [];
    try {
      final uri = Uri.parse(
        '$_apiUrl/general/search/single/?device_platform=webapp&aid=6383&keyword=${Uri.encodeComponent(query)}&count=$limit&offset=0',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['data'] as List? ?? [];
      return list
          .where((item) => item['aweme_info'] != null)
          .take(limit)
          .map((item) => _parseAweme(item['aweme_info']))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchRelated(String contentId, {int limit = 10}) async {
    if (!isAvailable) return [];
    try {
      final uri = Uri.parse(
        '$_apiUrl/related/recommend/?device_platform=webapp&aid=6383&aweme_id=$contentId&count=$limit',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data['aweme_list'] as List? ?? [];
      return list.take(limit).map(_parseAweme).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Recommendation?> getContentDetail(String contentId) async {
    if (!isAvailable) return null;
    try {
      final uri = Uri.parse(
        '$_apiUrl/aweme/detail/?device_platform=webapp&aid=6383&aweme_id=$contentId',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return _parseAweme(data['aweme_detail']);
    } catch (_) {
      return null;
    }
  }

  Recommendation _parseAweme(dynamic aweme) {
    final awemeId = aweme['aweme_id']?.toString() ?? '';
    final author = aweme['author'] ?? {};
    final statistics = aweme['statistics'] ?? {};
    final video = aweme['video'] ?? {};
    final cover = video['cover'] ?? {};
    final coverList = cover['url_list'] as List? ?? [];
    return Recommendation(
      bvid: 'dy:$awemeId',
      contentId: awemeId,
      itemKey: 'douyin:$awemeId',
      title: AppUtils.decodeHtml(aweme['desc']?.toString() ?? ''),
      upName: author['nickname']?.toString() ?? '',
      coverUrl: coverList.isNotEmpty ? coverList.first.toString() : '',
      contentUrl: '$_baseUrl/video/$awemeId',
      sourcePlatform: 'douyin',
      contentType: 'video',
      bodyText: aweme['desc']?.toString() ?? '',
      publishedAt: aweme['create_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((aweme['create_time'] as num).toInt() * 1000)
              .toIso8601String()
          : '',
      viewCount: _parseCount(statistics['play_count']),
      likeCount: _parseCount(statistics['digg_count']),
      commentCount: _parseCount(statistics['comment_count']),
      favoriteCount: _parseCount(statistics['collect_count']),
      shareCount: _parseCount(statistics['share_count']),
      duration: (video['duration'] as num?)?.toInt() ?? 0,
      topicLabel: (aweme['text_extra'] as List?)
              ?.map((t) => t['hashtag_name'])
              .whereType<String>()
              .take(3)
              .join('、') ??
          '',
    );
  }

  Recommendation _parseHotItem(dynamic item) {
    final word = item['word']?.toString() ?? '';
    return Recommendation(
      bvid: 'dy:hot_${item['position'] ?? word}',
      contentId: word,
      itemKey: 'douyin:hot_$word',
      title: word,
      upName: '抖音热榜',
      coverUrl: '',
      contentUrl: '$_baseUrl/search/?keyword=${Uri.encodeComponent(word)}',
      sourcePlatform: 'douyin',
      contentType: 'hot_topic',
      viewCount: _parseCount(item['hot_value']),
      topicLabel: '热榜 #${item['position']}',
    );
  }

  int _parseCount(dynamic value) {
    if (value is num) return value.toInt();
    final s = value?.toString() ?? '';
    if (s.isEmpty) return 0;
    if (s.contains('w')) return (double.tryParse(s.replaceAll('w', '')) ?? 0) * 10000 ~/ 1;
    return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  static List<String> get allCategories => _categories;
}
