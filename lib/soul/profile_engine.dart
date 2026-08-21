import 'dart:convert';
import '../models/profile.dart';
import '../models/delight.dart';
import '../models/chat.dart';
import '../database/repository.dart';
import '../llm/llm_service.dart';
import '../llm/prompts.dart';

class ProfileEngine {
  final AppRepository _repo = AppRepository();
  final LLMService _llm = LLMService.instance;

  ProfileEngine._internal();
  static final ProfileEngine instance = ProfileEngine._internal();

  ProfileSummary? _cachedProfile;
  DateTime? _lastUpdate;

  Future<ProfileSummary> getProfile({bool forceRefresh = false}) async {
    if (_cachedProfile != null && !forceRefresh && _lastUpdate != null) {
      if (DateTime.now().difference(_lastUpdate!).inMinutes < 5) {
        return _cachedProfile!;
      }
    }
    final profile = await _repo.getProfile();
    _cachedProfile = profile;
    _lastUpdate = DateTime.now();
    return profile;
  }

  Future<bool> get isInitialized async {
    final profile = await getProfile();
    return profile.initialized;
  }

  Future<ProfileSummary> generateProfile({bool fullRegeneration = false}) async {
    final events = await _repo.getRecentEvents(limit: 500);
    if (events.isEmpty && !fullRegeneration) {
      return _cachedProfile ?? const ProfileSummary();
    }

    if (!_llm.isReady) {
      return _generateHeuristicProfile(events);
    }

    final eventMaps = events.map((e) => {
      'event_type': e.eventType,
      'source_platform': e.sourcePlatform,
      'content_id': e.contentId,
      'title': e.title,
      'metadata': e.metadata,
      'created_at': e.createdAt.toIso8601String(),
    }).toList();

    final result = await _llm.chatJson(
      systemPrompt: LLMPrompts.systemBase,
      userPrompt: LLMPrompts.profileGeneration(eventMaps),
      temperature: 0.4,
      maxTokens: 8192,
    );

    if (result == null) {
      return _generateHeuristicProfile(events);
    }

    final profile = _parseProfileFromJson(result, events.length);
    await _repo.saveProfile(profile);
    _cachedProfile = profile;
    _lastUpdate = DateTime.now();
    return profile;
  }

  ProfileSummary _parseProfileFromJson(Map<String, dynamic> json, int eventCount) {
    return ProfileSummary(
      portrait: json['portrait']?.toString() ?? '',
      layers: (json['layers'] as List?)
              ?.map((e) => ProfileLayer.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      deepNeeds: (json['deep_needs'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      mbti: ProfileMbti.fromJson(
        json['mbti'] is Map ? Map<String, dynamic>.from(json['mbti']) : const {},
      ),
      values: (json['values'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      motivationalDrivers:
          (json['motivational_drivers'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      interests: (json['interests'] as List?)
              ?.map((e) => ProfileInterest.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      avoidances: (json['avoidances'] as List?)
              ?.map((e) => ProfileInterest.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      cognitiveStyle:
          (json['cognitive_style'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      style: ProfileStyle.fromJson(
        json['style'] is Map ? Map<String, dynamic>.from(json['style']) : const {},
      ),
      speculativeInterests: (json['speculative_interests'] as List?)
              ?.map((e) => ProfileSpeculation.fromJson(Map<String, dynamic>.from(e), avoidance: false))
              .toList() ??
          const [],
      explorationOpenness: (json['exploration_openness'] as num?)?.toDouble() ?? 0.5,
      initialized: true,
      updatedAt: DateTime.now(),
    );
  }

  ProfileSummary _generateHeuristicProfile(List<BehaviorEvent> events) {
    final interestMap = <String, double>{};
    final platformMap = <String, int>{};
    int likeCount = 0;
    int dislikeCount = 0;

    for (final event in events) {
      platformMap[event.sourcePlatform] = (platformMap[event.sourcePlatform] ?? 0) + 1;
      if (event.eventType == 'like' || event.eventType == 'save') {
        likeCount++;
        final title = event.title.toLowerCase();
        for (final keyword in _interestKeywords.entries) {
          if (title.contains(keyword.key)) {
            interestMap[keyword.value] = (interestMap[keyword.value] ?? 0) + event.weight;
          }
        }
      }
      if (event.eventType == 'dislike') {
        dislikeCount++;
      }
    }

    final sortedInterests = interestMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalWeight = sortedInterests.fold<double>(0, (sum, e) => sum + e.value);

    final interests = sortedInterests.take(10).map((e) {
      return ProfileInterest(
        name: e.key,
        weight: totalWeight > 0 ? e.value / totalWeight : 0,
        category: e.key,
        reason: '基于 ${events.where((ev) => ev.title.contains(e.key)).length} 次相关互动',
        interactionCount: events.where((ev) => ev.title.contains(e.key)).length,
      );
    }).toList();

    final topPlatform = platformMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ProfileSummary(
      portrait: '你主要在 ${topPlatform.isNotEmpty ? topPlatform.first.key : '多个平台'} 浏览内容，'
          '共产生 ${events.length} 次行为互动，其中喜欢/收藏 $likeCount 次，不感兴趣 $dislikeCount 次。'
          '随着更多互动积累，画像会越来越精准。',
      layers: [
        ProfileLayer(name: '内容探索者', summary: '活跃的跨平台内容消费者', weight: 0.8, level: 'event'),
        ProfileLayer(name: '偏好形成中', summary: '兴趣画像正在逐步清晰', weight: 0.6, level: 'preference'),
      ],
      deepNeeds: const ['信息获取', '娱乐放松', '兴趣探索'],
      interests: interests,
      avoidances: const [],
      cognitiveStyle: const ['视觉优先', '碎片化消费'],
      explorationOpenness: 0.5,
      initialized: events.length > 10,
      updatedAt: DateTime.now(),
    );
  }

  static const Map<String, String> _interestKeywords = {
    '游戏': '游戏', 'gaming': '游戏',
    '音乐': '音乐', 'music': '音乐', '歌': '音乐',
    '电影': '影视', 'movie': '影视', '剧': '影视',
    '科技': '科技', '数码': '科技', 'tech': '科技', '手机': '科技', '电脑': '科技',
    '美食': '美食', 'cooking': '美食', '吃': '美食',
    '旅行': '旅行', 'travel': '旅行', '旅游': '旅行',
    '健身': '健身', '运动': '健身', 'sport': '健身',
    '知识': '知识', '科普': '知识', '学习': '知识',
    '动漫': '动漫', 'anime': '动漫', '二次元': '动漫',
    '搞笑': '搞笑', '幽默': '搞笑',
    '时尚': '时尚', '穿搭': '时尚', 'fashion': '时尚',
    '汽车': '汽车', 'car': '汽车',
    '宠物': '萌宠', 'cat': '萌宠', 'dog': '萌宠',
    '财经': '财经', '股票': '财经', '理财': '财经',
    '历史': '历史', 'history': '历史',
    '心理': '心理学', 'psychology': '心理学',
    '编程': '编程', 'code': '编程', '程序': '编程',
  };

  Future<void> processFeedback({
    required String contentId,
    required String title,
    required String sourcePlatform,
    required String feedbackType,
    Map<String, dynamic> contentMetadata = const {},
  }) async {
    final event = BehaviorEvent(
      eventId: 'fb_${DateTime.now().millisecondsSinceEpoch}',
      eventType: feedbackType,
      sourcePlatform: sourcePlatform,
      contentId: contentId,
      title: title,
      metadata: contentMetadata,
      createdAt: DateTime.now(),
      weight: feedbackType == 'like' ? 2.0 : (feedbackType == 'dislike' ? 1.5 : 1.0),
    );
    await _repo.insertEvent(event);

    if (_llm.isReady) {
      final profile = await getProfile();
      final result = await _llm.chatJson(
        systemPrompt: LLMPrompts.systemBase,
        userPrompt: LLMPrompts.feedbackInterpretation(
          profile.toJson(),
          {'title': title, 'source_platform': sourcePlatform, ...contentMetadata},
          feedbackType,
        ),
        temperature: 0.3,
        maxTokens: 2048,
      );
      if (result != null && result['should_update_profile'] == true) {
        await _maybeAddCognitionUpdate(result);
      }
    }
  }

  Future<void> _maybeAddCognitionUpdate(Map<String, dynamic> result) async {
    final profile = await getProfile();
    final update = ProfileCognitionUpdate(
      summary: result['summary']?.toString() ?? '',
      impact: result['impact']?.toString() ?? 'medium',
      reasoning: result['reasoning']?.toString() ?? '',
      evidence: result['evidence']?.toString() ?? '',
      sourceLabel: 'feedback',
      createdAt: DateTime.now().toIso8601String(),
    );
    final newUpdates = [update, ...profile.cognitionUpdates].take(50).toList();
    final newProfile = ProfileSummary(
      portrait: profile.portrait,
      layers: profile.layers,
      deepNeeds: profile.deepNeeds,
      mbti: profile.mbti,
      values: profile.values,
      motivationalDrivers: profile.motivationalDrivers,
      interests: profile.interests,
      avoidances: profile.avoidances,
      favoriteUpUsers: profile.favoriteUpUsers,
      lifeStage: profile.lifeStage,
      currentPhase: profile.currentPhase,
      cognitiveStyle: profile.cognitiveStyle,
      style: profile.style,
      context: profile.context,
      explorationOpenness: profile.explorationOpenness,
      speculativeInterests: profile.speculativeInterests,
      speculativeAvoidances: profile.speculativeAvoidances,
      cognitionUpdates: newUpdates,
      activeInsights: profile.activeInsights,
      recentAwareness: profile.recentAwareness,
      overrides: profile.overrides,
      initialized: profile.initialized,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(newProfile);
    _cachedProfile = newProfile;
  }

  Future<List<PendingConfirmation>> generateInterestProbes() async {
    final profile = await getProfile();
    if (!_llm.isReady) return const [];

    final result = await _llm.chatJson(
      systemPrompt: LLMPrompts.systemBase,
      userPrompt: LLMPrompts.interestProbe(profile.toJson()),
      temperature: 0.6,
      maxTokens: 2048,
    );

    if (result == null) return const [];
    final probes = (result['probes'] as List?) ?? [];
    return probes.map((p) {
      final map = Map<String, dynamic>.from(p);
      return PendingConfirmation(
        kind: 'interest_probe',
        ref: 'probe_${DateTime.now().millisecondsSinceEpoch}_${map['domain']}',
        title: map['question']?.toString() ?? '',
        observation: map['domain']?.toString() ?? '',
        interpretation: map['why_now']?.toString() ?? '',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.now().toIso8601String(),
      );
    }).toList();
  }

  Future<void> confirmSpeculation(String domain, {required bool confirmed}) async {
    final profile = await getProfile();
    final speculations = profile.speculativeInterests.map((s) {
      if (s.domain == domain) {
        return ProfileSpeculation(
          domain: s.domain,
          reason: s.reason,
          confidence: confirmed ? 1.0 : 0.0,
          probeMode: s.probeMode,
          challenge: s.challenge,
          confirmationCount: confirmed ? s.confirmationThreshold : s.confirmationCount,
          confirmationThreshold: s.confirmationThreshold,
          specifics: s.specifics,
          avoidance: s.avoidance,
          status: confirmed ? 'confirmed' : 'rejected',
        );
      }
      return s;
    }).toList();

    final newProfile = ProfileSummary(
      portrait: profile.portrait,
      layers: profile.layers,
      deepNeeds: profile.deepNeeds,
      mbti: profile.mbti,
      values: profile.values,
      motivationalDrivers: profile.motivationalDrivers,
      interests: confirmed
          ? [
              ...profile.interests,
              ProfileInterest(name: domain, weight: 0.3, category: domain, reason: '用户确认感兴趣'),
            ]
          : profile.interests,
      avoidances: profile.avoidances,
      favoriteUpUsers: profile.favoriteUpUsers,
      lifeStage: profile.lifeStage,
      currentPhase: profile.currentPhase,
      cognitiveStyle: profile.cognitiveStyle,
      style: profile.style,
      context: profile.context,
      explorationOpenness: profile.explorationOpenness,
      speculativeInterests: speculations,
      speculativeAvoidances: profile.speculativeAvoidances,
      cognitionUpdates: profile.cognitionUpdates,
      activeInsights: profile.activeInsights,
      recentAwareness: profile.recentAwareness,
      overrides: profile.overrides,
      initialized: profile.initialized,
      updatedAt: DateTime.now(),
    );
    await _repo.saveProfile(newProfile);
    _cachedProfile = newProfile;
  }

  void invalidateCache() {
    _cachedProfile = null;
    _lastUpdate = null;
  }
}
