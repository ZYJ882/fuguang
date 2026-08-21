import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/recommendation.dart';
import '../models/profile.dart';
import '../models/chat.dart';
import '../models/saved_item.dart';
import '../models/delight.dart';
import '../database/repository.dart';
import '../recommendation/recommendation_engine.dart';
import '../soul/profile_engine.dart';
import '../chat/chat_engine.dart';
import '../llm/llm_service.dart';
import '../sources/source_manager.dart';

class AppState extends ChangeNotifier {
  final AppRepository _repo = AppRepository();
  final RecommendationEngine _recEngine = RecommendationEngine.instance;
  final ProfileEngine _profileEngine = ProfileEngine.instance;
  final ChatEngine _chatEngine = ChatEngine.instance;
  final LLMService _llm = LLMService.instance;
  final SourceManager _sources = SourceManager.instance;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> init() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _llm.init();
      await _sources.init();
      _initialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class RecommendProvider extends ChangeNotifier {
  final RecommendationEngine _engine = RecommendationEngine.instance;
  final AppRepository _repo = AppRepository();

  List<Recommendation> _recommendations = [];
  List<Recommendation> get recommendations => _recommendations;

  DelightCard? _delight;
  DelightCard? get delight => _delight;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Future<void> loadRecommendations({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _recommendations = await _engine.getRecommendations(
        limit: 20,
        forceRefresh: forceRefresh,
      );
      _hasMore = _recommendations.length >= 20;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reshuffle() async {
    _isLoading = true;
    notifyListeners();
    try {
      _recommendations = await _engine.reshuffle(limit: 20);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDelight() async {
    try {
      _delight = await _engine.generateDelight();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> recordClick(Recommendation rec) async {
    await _engine.recordClick(rec);
  }

  Future<void> recordFeedback(Recommendation rec, String feedbackType) async {
    await _engine.recordFeedback(rec, feedbackType);
    _recommendations = _recommendations.map((r) {
      if (r.itemKey == rec.itemKey) {
        return Recommendation(
          id: r.id,
          bvid: r.bvid,
          itemKey: r.itemKey,
          contentId: r.contentId,
          title: r.title,
          upName: r.upName,
          coverUrl: r.coverUrl,
          expression: r.expression,
          topicLabel: r.topicLabel,
          contentUrl: r.contentUrl,
          sourcePlatform: r.sourcePlatform,
          contentType: r.contentType,
          bodyText: r.bodyText,
          publishedAt: r.publishedAt,
          publishedLabel: r.publishedLabel,
          viewCount: r.viewCount,
          likeCount: r.likeCount,
          commentCount: r.commentCount,
          favoriteCount: r.favoriteCount,
          danmakuCount: r.danmakuCount,
          ratingScore: r.ratingScore,
          ratingCount: r.ratingCount,
          sourceRank: r.sourceRank,
          duration: r.duration,
          tags: r.tags,
          feedbackType: feedbackType,
          matchScore: r.matchScore,
          recommendReason: r.recommendReason,
        );
      }
      return r;
    }).toList();
    notifyListeners();
  }

  Future<void> ackDelight(String delightId, String status) async {
    await _repo.updateDelightStatus(delightId, status);
    if (_delight?.delightId == delightId) {
      _delight = null;
      notifyListeners();
    }
  }

  Future<List<Recommendation>> search(String query) async {
    return _engine.search(query, limit: 20);
  }
}

class ProfileProvider extends ChangeNotifier {
  final ProfileEngine _engine = ProfileEngine.instance;

  ProfileSummary _profile = const ProfileSummary();
  ProfileSummary get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadProfile({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _engine.getProfile(forceRefresh: forceRefresh);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> regenerateProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      _profile = await _engine.generateProfile(fullRegeneration: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmSpeculation(String domain, bool confirmed) async {
    await _engine.confirmSpeculation(domain, confirmed: confirmed);
    await loadProfile(forceRefresh: true);
  }
}

class ChatProvider extends ChangeNotifier {
  final ChatEngine _engine = ChatEngine.instance;

  List<ChatTurn> _messages = [];
  List<ChatTurn> get messages => _messages;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _isSending = false;
  bool get isSending => _isSending;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _messages = await _engine.getChatHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNotifications() async {
    try {
      _notifications = await _engine.getNotifications();
      _unreadCount = await _engine.getUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty || _isSending) return;
    _isSending = true;
    notifyListeners();
    try {
      final reply = await _engine.sendMessage(message: message);
      _messages = await _engine.getChatHistory();
      if (reply.status == 'error') {
        _error = reply.error;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String id) async {
    await _engine.markNotificationRead(id);
    _unreadCount = await _engine.getUnreadCount();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await _engine.markAllRead();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> respondToConfirmation(String ref, String response,
      {String? discussion}) async {
    await _engine.respondToConfirmation(
        ref: ref, response: response, discussion: discussion);
    await loadNotifications();
  }
}

class SavedProvider extends ChangeNotifier {
  final AppRepository _repo = AppRepository();

  List<SavedItem> _watchLater = [];
  List<SavedItem> get watchLater => _watchLater;

  List<SavedItem> _favorites = [];
  List<SavedItem> get favorites => _favorites;

  List<ContentHistoryItem> _history = [];
  List<ContentHistoryItem> get history => _history;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      _watchLater = await _repo.getSavedItems(listKind: 'watch_later');
      _favorites = await _repo.getSavedItems(listKind: 'favorite');
      _history = await _repo.getHistory(days: 30, limit: 100);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToWatchLater(Recommendation rec) async {
    final item = SavedItem(
      itemKey: rec.savedIdentity,
      sourcePlatform: rec.sourcePlatform,
      contentId: rec.contentId,
      contentUrl: rec.contentUrl,
      contentType: rec.contentType,
      title: rec.title,
      authorName: rec.upName,
      coverUrl: rec.coverUrl,
      listKind: 'watch_later',
      savedAt: DateTime.now(),
    );
    await _repo.saveItem(item);
    await loadAll();
  }

  Future<void> addToFavorites(Recommendation rec) async {
    final item = SavedItem(
      itemKey: rec.savedIdentity,
      sourcePlatform: rec.sourcePlatform,
      contentId: rec.contentId,
      contentUrl: rec.contentUrl,
      contentType: rec.contentType,
      title: rec.title,
      authorName: rec.upName,
      coverUrl: rec.coverUrl,
      listKind: 'favorite',
      savedAt: DateTime.now(),
    );
    await _repo.saveItem(item);
    await loadAll();
  }

  Future<void> removeFromWatchLater(String itemKey) async {
    await _repo.removeItem(itemKey, 'watch_later');
    await loadAll();
  }

  Future<void> removeFromFavorites(String itemKey) async {
    await _repo.removeItem(itemKey, 'favorite');
    await loadAll();
  }

  Future<bool> isInWatchLater(String itemKey) async {
    return _repo.isItemSaved(itemKey, 'watch_later');
  }

  Future<bool> isInFavorites(String itemKey) async {
    return _repo.isItemSaved(itemKey, 'favorite');
  }
}

class SettingsProvider extends ChangeNotifier {
  static const _themeModeConfigKey = 'theme_mode';
  final LLMService _llm = LLMService.instance;
  final SourceManager _sources = SourceManager.instance;
  final AppRepository _repo = AppRepository();

  LLMConfig _llmConfig = const LLMConfig();
  LLMConfig get llmConfig => _llmConfig;

  Map<String, bool> _sourceEnabled = {};
  Map<String, bool> get sourceEnabled => _sourceEnabled;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool get darkMode => _themeMode == ThemeMode.dark;

  bool _autoSync = true;
  bool get autoSync => _autoSync;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      _llmConfig = _llm.config;
      for (final platform in [
        'bilibili',
        'xiaohongshu',
        'douyin',
        'zhihu',
        'web'
      ]) {
        final config = _sources.getConfig(platform);
        _sourceEnabled[platform] = config?.enabled ?? true;
      }
      final storedThemeMode = await _repo.getConfig(_themeModeConfigKey);
      switch (storedThemeMode) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
        default:
          // 兼容旧版：原“深色模式”关闭时等同于跟随系统。
          _themeMode = (await _repo.getConfig('dark_mode')) == 'true'
              ? ThemeMode.dark
              : ThemeMode.system;
      }
      _autoSync = (await _repo.getConfig('auto_sync')) != 'false';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLLMConfig(LLMConfig config) async {
    await _llm.updateConfig(config);
    _llmConfig = _llm.config;
    notifyListeners();
  }

  Future<LLMConfig> selectLLMProvider(String providerId) async {
    _llmConfig = await _llm.selectProvider(providerId);
    notifyListeners();
    return _llmConfig;
  }

  Future<ModelListResult> fetchLLMModels() async {
    return _llm.fetchModels();
  }

  Future<bool> testLLMConnection() async {
    return _llm.testConnection();
  }

  Future<void> setSourceEnabled(String platform, bool enabled) async {
    await _sources.setSourceEnabled(platform, enabled);
    _sourceEnabled[platform] = enabled;
    notifyListeners();
  }

  Future<void> setSourceCookies(String platform, String cookies) async {
    await _sources.setSourceCookies(platform, cookies);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _repo.setConfig(_themeModeConfigKey, value.name);
    notifyListeners();
  }

  // 保留旧调用入口，方便平滑兼容后续代码。
  Future<void> setDarkMode(bool value) {
    return setThemeMode(value ? ThemeMode.dark : ThemeMode.system);
  }

  Future<void> setAutoSync(bool value) async {
    _autoSync = value;
    await _repo.setConfig('auto_sync', value.toString());
    notifyListeners();
  }

  bool get llmReady => _llm.isReady;
  List<String> get availableSources => _sources.availablePlatforms;
}
