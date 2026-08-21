import '../models/recommendation.dart';
import '../database/repository.dart';
import 'base_source.dart';
import 'bilibili_source.dart';
import 'xiaohongshu_source.dart';
import 'douyin_source.dart';
import 'zhihu_source.dart';
import 'web_source.dart';

class SourceManager {
  final AppRepository _repo = AppRepository();
  final Map<String, ContentSource> _sources = {};
  final Map<String, SourceConfig> _configs = {};

  SourceManager._internal();
  static final SourceManager instance = SourceManager._internal();

  Future<void> init() async {
    _sources['bilibili'] = BilibiliSource();
    _sources['xiaohongshu'] = XiaohongshuSource();
    _sources['douyin'] = DouyinSource();
    _sources['zhihu'] = ZhihuSource();
    _sources['web'] = WebSource();

    for (final entry in _sources.entries) {
      final creds = await _repo.getCredentials(entry.key);
      if (creds['cookies']?.isNotEmpty ?? false) {
        _setSourceCookies(entry.key, creds['cookies']!);
      }
      final enabledStr = await _repo.getConfig('source_${entry.key}_enabled');
      _configs[entry.key] = SourceConfig(
        platform: entry.key,
        enabled: enabledStr != 'false',
        priority: int.tryParse(await _repo.getConfig('source_${entry.key}_priority') ?? '5') ?? 5,
        dailyFetchLimit:
            int.tryParse(await _repo.getConfig('source_${entry.key}_limit') ?? '100') ?? 100,
        cookies: creds['cookies'],
        token: creds['token'],
      );
    }
  }

  void _setSourceCookies(String platform, String cookies) {
    final source = _sources[platform];
    if (source is BilibiliSource) source.setCookies(cookies);
    if (source is XiaohongshuSource) source.setCookies(cookies);
    if (source is DouyinSource) source.setCookies(cookies);
    if (source is ZhihuSource) source.setCookies(cookies);
  }

  List<String> get availablePlatforms =>
      _sources.entries.where((e) => e.value.isAvailable).map((e) => e.key).toList();

  List<String> get enabledPlatforms =>
      _configs.entries.where((e) => e.value.enabled).map((e) => e.key).toList();

  ContentSource? getSource(String platform) => _sources[platform];

  SourceConfig? getConfig(String platform) => _configs[platform];

  Future<void> setSourceEnabled(String platform, bool enabled) async {
    _configs[platform] = _configs[platform]?.copyWith(enabled: enabled) ??
        SourceConfig(platform: platform, enabled: enabled);
    await _repo.setConfig('source_${platform}_enabled', enabled.toString());
  }

  Future<void> setSourceCookies(String platform, String cookies) async {
    await _repo.saveCredentials(platform, cookies);
    _setSourceCookies(platform, cookies);
    _configs[platform] = _configs[platform]?.copyWith(cookies: cookies) ??
        SourceConfig(platform: platform, cookies: cookies);
  }

  Future<List<Recommendation>> fetchFromAllSources({
    int perSourceLimit = 20,
    List<String>? platforms,
  }) async {
    final targets = platforms ?? enabledPlatforms;
    final results = <Recommendation>[];
    for (final platform in targets) {
      final source = _sources[platform];
      if (source == null || !source.isAvailable) continue;
      try {
        final items = await source.fetchTrending(limit: perSourceLimit);
        results.addAll(items);
      } catch (_) {}
    }
    return results;
  }

  Future<List<Recommendation>> fetchByCategory(
    String category, {
    int perSourceLimit = 15,
    List<String>? platforms,
  }) async {
    final targets = platforms ?? enabledPlatforms;
    final results = <Recommendation>[];
    for (final platform in targets) {
      final source = _sources[platform];
      if (source == null || !source.isAvailable) continue;
      try {
        final items = await source.fetchByCategory(category, limit: perSourceLimit);
        results.addAll(items);
      } catch (_) {}
    }
    return results;
  }

  Future<List<Recommendation>> searchAll(
    String query, {
    int perSourceLimit = 10,
    List<String>? platforms,
  }) async {
    final targets = platforms ?? enabledPlatforms;
    final results = <Recommendation>[];
    for (final platform in targets) {
      final source = _sources[platform];
      if (source == null || !source.isAvailable) continue;
      try {
        final items = await source.search(query, limit: perSourceLimit);
        results.addAll(items);
      } catch (_) {}
    }
    return results;
  }

  Future<List<Recommendation>> fetchRelated(
    String platform,
    String contentId, {
    int limit = 10,
  }) async {
    final source = _sources[platform];
    if (source == null || !source.isAvailable) return [];
    try {
      return await source.fetchRelated(contentId, limit: limit);
    } catch (_) {
      return [];
    }
  }

  Map<String, List<String>> getAllCategories() {
    return {
      'bilibili': BilibiliSource.allCategories,
      'xiaohongshu': XiaohongshuSource.allCategories,
      'douyin': DouyinSource.allCategories,
      'zhihu': ZhihuSource.allCategories,
      'web': WebSource.allCategories,
    };
  }
}
