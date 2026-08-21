import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation.dart';
import '../utils/app_utils.dart';
import 'base_source.dart';

class XiaohongshuSource extends ContentSource {
  final http.Client _client = http.Client();
  String? _cookies;

  static const String _baseUrl = 'https://edith.xiaohongshu.com';
  static const String _webUrl = 'https://www.xiaohongshu.com';

  static const List<String> _categories = [
    '推荐', '穿搭', '美食', '彩妆', '影视', '职场', '情感',
    '家居', '游戏', '旅行', '健身', '读书', '科技', '萌宠',
    '摄影', '音乐', '舞蹈', '运动', '汽车', '动漫',
  ];

  @override
  String get platform => 'xiaohongshu';
  @override
  String get platformLabel => '小红书';
  @override
  bool get requiresAuth => true;
  @override
  bool get isAvailable => _cookies != null && _cookies!.isNotEmpty;

  void setCookies(String cookies) => _cookies = cookies;

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': '$_webUrl/',
    'Accept': 'application/json, text/plain, */*',
    if (_cookies != null) 'Cookie': _cookies!,
  };

  @override
  Future<List<Recommendation>> fetchTrending({int limit = 30}) async {
    if (!isAvailable) return [];
    try {
      final uri = Uri.parse('$_webUrl/api/sns/web/v1/homefeed');
      final body = jsonEncode({
        'cursor_score': '',
        'num': limit,
        'refresh_type': 1,
        'note_index': 0,
        'unread_begin_note_id': '',
        'unread_end_note_id': '',
        'unread_note_count': 0,
        'category': 'homefeed_recommend',
        'search_key': '',
        'need_num': limit,
        'image_formats': ['jpg', 'webp', 'avif'],
      });
      final res = await _client
          .post(uri, headers: {..._headers, 'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final items = data['data']['items'] as List? ?? [];
      return items.take(limit).map(_parseNote).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchByCategory(String category, {int limit = 30}) async {
    if (!isAvailable) return [];
    try {
      final uri = Uri.parse('$_webUrl/api/sns/web/v1/homefeed');
      final body = jsonEncode({
        'cursor_score': '',
        'num': limit,
        'refresh_type': 1,
        'note_index': 0,
        'category': 'homefeed_$category',
        'search_key': '',
        'need_num': limit,
        'image_formats': ['jpg', 'webp', 'avif'],
      });
      final res = await _client
          .post(uri, headers: {..._headers, 'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final items = data['data']['items'] as List? ?? [];
      return items.take(limit).map(_parseNote).toList();
    } catch (_) {
      return search(category, limit: limit);
    }
  }

  @override
  Future<List<Recommendation>> search(String query, {int limit = 20}) async {
    if (!isAvailable) return [];
    try {
      final uri = Uri.parse(
        '$_webUrl/api/sns/web/v1/search/notes?keyword=${Uri.encodeComponent(query)}&page=1&page_size=$limit&search_id=&sort=general&note_type=0',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final items = data['data']['items'] as List? ?? [];
      return items.take(limit).map(_parseSearchNote).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recommendation>> fetchRelated(String contentId, {int limit = 10}) async {
    if (!isAvailable) return [];
    try {
      final uri = Uri.parse(
        '$_webUrl/api/sns/web/v1/related/feed?note_id=$contentId&num=$limit',
      );
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final items = data['data']['items'] as List? ?? [];
      return items.take(limit).map(_parseNote).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Recommendation?> getContentDetail(String contentId) async {
    if (!isAvailable) return null;
    try {
      final uri = Uri.parse('$_webUrl/api/sns/web/v1/feed?source_note_id=$contentId');
      final res = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final items = data['data']['items'] as List? ?? [];
      if (items.isEmpty) return null;
      return _parseNote(items.first);
    } catch (_) {
      return null;
    }
  }

  Recommendation _parseNote(dynamic item) {
    final note = item['note_card'] ?? item;
    final noteId = note['id']?.toString() ?? note['note_id']?.toString() ?? '';
    final user = note['user'] ?? {};
    final interact = note['interact_info'] ?? {};
    final cover = note['cover'] ?? {};
    final imageList = cover['url_list'] as List? ?? [];
    return Recommendation(
      bvid: 'xhs:$noteId',
      contentId: noteId,
      itemKey: 'xiaohongshu:$noteId',
      title: AppUtils.decodeHtml(note['title']?.toString() ?? note['desc']?.toString() ?? ''),
      upName: user['nickname']?.toString() ?? '',
      coverUrl: imageList.isNotEmpty ? imageList.first.toString() : '',
      contentUrl: '$_webUrl/explore/$noteId',
      sourcePlatform: 'xiaohongshu',
      contentType: note['type']?.toString() == 'video' ? 'video' : 'note',
      bodyText: note['desc']?.toString() ?? '',
      publishedAt: note['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((note['time'] as num).toInt()).toIso8601String()
          : '',
      likeCount: _parseCount(interact['liked_count']),
      commentCount: _parseCount(interact['comment_count']),
      favoriteCount: _parseCount(interact['collected_count']),
      shareCount: _parseCount(interact['share_count']),
      topicLabel: (note['tag_list'] as List?)?.map((t) => t['name']).join('、') ?? '',
    );
  }

  Recommendation _parseSearchNote(dynamic item) {
    final note = item['note_card'] ?? item;
    final noteId = note['id']?.toString() ?? '';
    return Recommendation(
      bvid: 'xhs:$noteId',
      contentId: noteId,
      itemKey: 'xiaohongshu:$noteId',
      title: AppUtils.decodeHtml(note['title']?.toString() ?? note['desc']?.toString() ?? ''),
      upName: note['user']?['nickname']?.toString() ?? '',
      coverUrl: (note['cover']?['url_list'] as List?)?.first.toString() ?? '',
      contentUrl: '$_webUrl/explore/$noteId',
      sourcePlatform: 'xiaohongshu',
      contentType: 'note',
      likeCount: _parseCount(note['interact_info']?['liked_count']),
    );
  }

  int _parseCount(dynamic value) {
    if (value is num) return value.toInt();
    final s = value?.toString() ?? '';
    if (s.isEmpty) return 0;
    if (s.contains('万')) return (double.tryParse(s.replaceAll('万', '')) ?? 0) * 10000 ~/ 1;
    return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  static List<String> get allCategories => _categories;
}
