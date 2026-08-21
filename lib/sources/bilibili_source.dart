import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';
import '../utils/app_utils.dart';
import 'base_source.dart';

class BilibiliSource extends ContentSource {
  final http.Client _client = http.Client();
  String? _cookies;

  static const String _baseUrl = 'https://api.bilibili.com';
  static const String _appBaseUrl = 'https://app.bilibili.com';

  static const Map<int, String> _categories = {
    1: '动画',
    3: '音乐',
    4: '游戏',
    5: '娱乐',
    11: '电视剧',
    13: '番剧',
    17: '单机游戏',
    21: '日常',
    36: '知识',
    119: '鬼畜',
    129: '舞蹈',
    155: '时尚',
    160: '生活',
    167: '国创',
    177: '纪录片',
    181: '影视',
    188: '科技',
    202: '资讯',
    211: '美食',
    217: '动物圈',
    223: '汽车',
    234: '运动',
    243: '健身',
    250: '科普',
  };

  @override
  String get platform => 'bilibili';

  @override
  String get platformLabel => 'B站';

  @override
  bool get requiresAuth => false;

  @override
  bool get isAvailable => true;

  void setCookies(String cookies) {
    _cookies = cookies;
  }

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://www.bilibili.com',
    'Accept': 'application/json, text/plain, */*',
    if (_cookies != null) 'Cookie': _cookies!,
  };

  @override
  Future<List<Recommendation>> fetchTrending({int limit = 30}) async {
    try {
      final uri = Uri.parse('$_baseUrl/x/web-interface/popular?ps=$limit&pn=1');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data['code'] != 0) return [];
      final list = data['data']['list'] as List? ?? [];
      return list.take(limit).map(_parseVideo).toList();
    } catch (_) {
      return _fallbackRanking(limit);
    }
  }

  Future<List<Recommendation>> _fallbackRanking(int limit) async {
    try {
      final uri = Uri.parse('$_baseUrl/x/web-interface/ranking/v2?rid=0&type=all');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data['code'] != 0) return [];
      final list = data['data']['list'] as List? ?? [];
      return list.take(limit).map(_parseVideo).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchByCategory(String category, {int limit = 30}) async {
    try {
      final rid = _categories.entries
          .firstWhere(
            (e) => e.value == category || e.key.toString() == category,
            orElse: () => const MapEntry(0, ''),
          )
          .key;
      if (rid == 0) return search(category, limit: limit);
      final uri = Uri.parse(
        '$_baseUrl/x/web-interface/dynamic/region?ps=$limit&rid=$rid&pn=1',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data['code'] != 0) return [];
      final list = data['data']['archives'] as List? ?? [];
      return list.take(limit).map(_parseVideo).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> search(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/x/web-interface/search/type?search_type=video&keyword=${Uri.encodeComponent(query)}&page=1&page_size=$limit',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data['code'] != 0) return [];
      final list = data['data']['result'] as List? ?? [];
      return list.take(limit).map(_parseSearchResult).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchRelated(String contentId, {int limit = 10}) async {
    try {
      final bvid = contentId.startsWith('BV') ? contentId : '';
      if (bvid.isEmpty) return [];
      final uri = Uri.parse('$_baseUrl/x/web-interface/archive/related?bvid=$bvid');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data['code'] != 0) return [];
      final list = data['data'] as List? ?? [];
      return list.take(limit).map(_parseVideo).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Recommendation?> getContentDetail(String contentId) async {
    try {
      final bvid = contentId.startsWith('BV') ? contentId : '';
      if (bvid.isEmpty) return null;
      final uri = Uri.parse('$_baseUrl/x/web-interface/view?bvid=$bvid');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data['code'] != 0) return null;
      return _parseVideo(data['data']);
    } catch (_) {
      return null;
    }
  }

  Recommendation _parseVideo(dynamic item) {
    final bvid = item['bvid']?.toString() ?? '';
    final owner = item['owner'] is Map ? item['owner'] : {};
    final stat = item['stat'] is Map ? item['stat'] : {};
    return Recommendation(
      bvid: bvid,
      contentId: bvid,
      itemKey: 'bilibili:$bvid',
      title: AppUtils.decodeHtml(item['title']?.toString() ?? ''),
      upName: owner['name']?.toString() ?? '',
      coverUrl: (item['pic']?.toString() ?? '').replaceFirst('http://', 'https://'),
      contentUrl: 'https://www.bilibili.com/video/$bvid',
      sourcePlatform: 'bilibili',
      contentType: 'video',
      bodyText: item['desc']?.toString() ?? '',
      publishedAt: item['pubdate'] != null
          ? DateTime.fromMillisecondsSinceEpoch((item['pubdate'] as num).toInt() * 1000)
              .toIso8601String()
          : '',
      viewCount: (stat['view'] as num?)?.toInt() ?? 0,
      likeCount: (stat['like'] as num?)?.toInt() ?? 0,
      commentCount: (stat['reply'] as num?)?.toInt() ?? 0,
      favoriteCount: (stat['favorite'] as num?)?.toInt() ?? 0,
      danmakuCount: (stat['danmaku'] as num?)?.toInt() ?? 0,
      duration: (item['duration'] as num?)?.toInt() ?? 0,
      tags: (item['tid'] != null) ? [_categories[item['tid']] ?? ''] : const [],
      topicLabel: item['tname']?.toString() ?? '',
    );
  }

  Recommendation _parseSearchResult(dynamic item) {
    final bvid = item['bvid']?.toString() ?? '';
    return Recommendation(
      bvid: bvid,
      contentId: bvid,
      itemKey: 'bilibili:$bvid',
      title: AppUtils.decodeHtml(
        (item['title']?.toString() ?? '').replaceAll(RegExp(r'<[^>]+>'), ''),
      ),
      upName: item['author']?.toString() ?? '',
      coverUrl: (item['pic']?.toString() ?? '').replaceFirst('http://', 'https://'),
      contentUrl: 'https://www.bilibili.com/video/$bvid',
      sourcePlatform: 'bilibili',
      contentType: 'video',
      viewCount: _parseCount(item['play']),
      likeCount: _parseCount(item['like']),
      commentCount: _parseCount(item['review']),
      favoriteCount: _parseCount(item['favorites']),
      danmakuCount: _parseCount(item['video_review']),
      duration: _parseDuration(item['duration']?.toString() ?? ''),
      topicLabel: item['typename']?.toString() ?? '',
    );
  }

  int _parseCount(dynamic value) {
    if (value is num) return value.toInt();
    final s = value?.toString() ?? '';
    if (s.isEmpty) return 0;
    if (s.contains('万')) {
      return (double.tryParse(s.replaceAll('万', '')) ?? 0) * 10000 ~/ 1;
    }
    if (s.contains('亿')) {
      return (double.tryParse(s.replaceAll('亿', '')) ?? 0) * 100000000 ~/ 1;
    }
    return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int _parseDuration(String duration) {
    final parts = duration.split(':');
    if (parts.length == 2) {
      return int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
    }
    if (parts.length == 3) {
      return int.tryParse(parts[0])! * 3600 +
          int.tryParse(parts[1])! * 60 +
          int.tryParse(parts[2])!;
    }
    return 0;
  }

  static List<String> get allCategories => _categories.values.toList();
}
