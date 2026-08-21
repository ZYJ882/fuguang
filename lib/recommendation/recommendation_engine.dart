import 'dart:math';
import '../models/recommendation.dart';
import '../models/profile.dart';
import '../models/delight.dart';
import '../models/saved_item.dart';
import '../database/repository.dart';
import '../sources/source_manager.dart';
import '../llm/llm_service.dart';
import '../llm/prompts.dart';
import '../soul/profile_engine.dart';

class RecommendationEngine {
  final AppRepository _repo = AppRepository();
  final SourceManager _sources = SourceManager.instance;
  final LLMService _llm = LLMService.instance;
  final ProfileEngine _profileEngine = ProfileEngine.instance;

  RecommendationEngine._internal();
  static final RecommendationEngine instance = RecommendationEngine._internal();

  final Random _random = Random();
  static const int _poolTargetSize = 200;
  static const int _refreshBatchSize = 50;
  static const double _topicDedupThreshold = 0.1;

  Future<List<Recommendation>> getRecommendations({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final poolSize = await _repo.getPoolSize();
    if (forceRefresh || poolSize < _poolTargetSize ~/ 2) {
      await _refreshPool();
    }

    final profile = await _profileEngine.getProfile();
    var candidates = await _repo.getRecommendations(limit: 100);

    candidates = await _scoreAndRank(candidates, profile);
    candidates = _applyDedupAndFatigue(candidates);
    candidates = _applyDiversity(candidates);

    final results = candidates.take(limit).toList();
    for (final rec in results) {
      await _repo.incrementShowCount(rec.itemKey);
      await _recordImpression(rec);
    }
    return results;
  }

  Future<void> _refreshPool() async {
    final profile = await _profileEngine.getProfile();
    final fetched = <Recommendation>[];

    final trending = await _sources.fetchFromAllSources(perSourceLimit: 15);
    fetched.addAll(trending);

    if (profile.interests.isNotEmpty) {
      for (final interest in profile.interests.take(3)) {
        final byCategory = await _sources.fetchByCategory(
          interest.name,
          perSourceLimit: 10,
        );
        fetched.addAll(byCategory);
      }
    }

    if (profile.speculativeInterests.isNotEmpty) {
      for (final spec in profile.speculativeInterests.take(2)) {
        if (spec.confidence > 0.3) {
          final speculative = await _sources.searchAll(
            spec.domain,
            perSourceLimit: 5,
          );
          fetched.addAll(speculative);
        }
      }
    }

    final deduped = _deduplicate(fetched);
    await _repo.upsertRecommendations(deduped);
    await _repo.cleanupOldPool(maxRows: _poolTargetSize);
  }

  List<Recommendation> _deduplicate(List<Recommendation> items) {
    final seen = <String>{};
    final result = <Recommendation>[];
    for (final item in items) {
      final key = item.itemKey.isNotEmpty ? item.itemKey : '${item.sourcePlatform}:${item.contentId}';
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(item);
    }
    return result;
  }

  Future<List<Recommendation>> _scoreAndRank(
    List<Recommendation> candidates,
    ProfileSummary profile,
  ) async {
    final scored = <Recommendation>[];
    for (final rec in candidates) {
      double score = 0.5;

      score += _interestMatchScore(rec, profile) * 0.4;
      score += _qualityScore(rec) * 0.2;
      score += _freshnessScore(rec) * 0.15;
      score += _diversityBonus(rec, scored) * 0.15;
      score += _explorationBonus(rec, profile) * 0.1;
      score -= _fatiguePenalty(rec);

      score = score.clamp(0.0, 1.0);

      String reason = '';
      if (_llm.isReady && score > 0.6 && rec.recommendReason.isEmpty) {
        reason = await _generateReason(rec, profile);
      }

      scored.add(Recommendation(
        id: rec.id,
        bvid: rec.bvid,
        itemKey: rec.itemKey,
        contentId: rec.contentId,
        title: rec.title,
        upName: rec.upName,
        coverUrl: rec.coverUrl,
        expression: rec.expression,
        topicLabel: rec.topicLabel,
        contentUrl: rec.contentUrl,
        sourcePlatform: rec.sourcePlatform,
        contentType: rec.contentType,
        bodyText: rec.bodyText,
        publishedAt: rec.publishedAt,
        publishedLabel: rec.publishedLabel,
        viewCount: rec.viewCount,
        likeCount: rec.likeCount,
        commentCount: rec.commentCount,
        favoriteCount: rec.favoriteCount,
        danmakuCount: rec.danmakuCount,
        ratingScore: rec.ratingScore,
        ratingCount: rec.ratingCount,
        sourceRank: rec.sourceRank,
        duration: rec.duration,
        tags: rec.tags,
        feedbackType: rec.feedbackType,
        matchScore: score,
        recommendReason: reason.isNotEmpty ? reason : rec.recommendReason,
      ));
    }

    scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return scored;
  }

  double _interestMatchScore(Recommendation rec, ProfileSummary profile) {
    if (profile.interests.isEmpty) return 0.5;
    final text = '${rec.title} ${rec.topicLabel} ${rec.tags.join(' ')} ${rec.bodyText}'.toLowerCase();
    double maxMatch = 0;
    for (final interest in profile.interests) {
      if (text.contains(interest.name.toLowerCase())) {
        maxMatch = max(maxMatch, interest.weight);
      }
      for (final specific in interest.specifics) {
        if (text.contains(specific.toLowerCase())) {
          maxMatch = max(maxMatch, interest.weight * 0.8);
        }
      }
    }
    for (final avoidance in profile.avoidances) {
      if (text.contains(avoidance.name.toLowerCase())) {
        maxMatch -= avoidance.weight * 0.5;
      }
    }
    return maxMatch.clamp(0.0, 1.0);
  }

  double _qualityScore(Recommendation rec) {
    double score = 0.5;
    if (rec.viewCount > 1000000) score += 0.2;
    else if (rec.viewCount > 100000) score += 0.1;
    if (rec.likeCount > 10000) score += 0.1;
    if (rec.favoriteCount > 5000) score += 0.1;
    if (rec.ratingScore > 8) score += 0.1;
    if (rec.title.length < 5) score -= 0.2;
    return score.clamp(0.0, 1.0);
  }

  double _freshnessScore(Recommendation rec) {
    if (rec.publishedAt.isEmpty) return 0.5;
    final published = DateTime.tryParse(rec.publishedAt);
    if (published == null) return 0.5;
    final age = DateTime.now().difference(published).inDays;
    if (age < 1) return 1.0;
    if (age < 7) return 0.9;
    if (age < 30) return 0.7;
    if (age < 90) return 0.5;
    return 0.3;
  }

  double _diversityBonus(Recommendation rec, List<Recommendation> current) {
    if (current.isEmpty) return 0.5;
    final samePlatform = current.where((r) => r.sourcePlatform == rec.sourcePlatform).length;
    final sameTopic = current.where((r) => r.topicLabel == rec.topicLabel).length;
    double bonus = 0.5;
    if (samePlatform < 2) bonus += 0.3;
    if (sameTopic == 0) bonus += 0.2;
    return bonus.clamp(0.0, 1.0);
  }

  double _explorationBonus(Recommendation rec, ProfileSummary profile) {
    if (profile.speculativeInterests.isEmpty) return 0.3;
    final text = '${rec.title} ${rec.topicLabel}'.toLowerCase();
    for (final spec in profile.speculativeInterests) {
      if (text.contains(spec.domain.toLowerCase()) && !spec.avoidance) {
        return 0.5 + spec.confidence * 0.5;
      }
    }
    return 0.3;
  }

  double _fatiguePenalty(Recommendation rec) {
    if (rec.feedbackType == 'dislike') return 1.0;
    if (rec.feedbackType == 'like') return -0.2;
    return 0;
  }

  List<Recommendation> _applyDedupAndFatigue(List<Recommendation> items) {
    final topicCounts = <String, int>{};
    final result = <Recommendation>[];
    for (final rec in items) {
      final topic = rec.topicLabel.isEmpty ? rec.sourcePlatform : rec.topicLabel;
      topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      final total = items.length;
      if (total > 0 && topicCounts[topic]! / total > _topicDedupThreshold + 0.2) {
        continue;
      }
      result.add(rec);
    }
    return result;
  }

  List<Recommendation> _applyDiversity(List<Recommendation> items) {
    if (items.length < 10) return items;
    final result = <Recommendation>[];
    final platformSlots = <String, int>{};
    final maxPerPlatform = max(3, items.length ~/ 4);
    for (final rec in items) {
      final count = platformSlots[rec.sourcePlatform] ?? 0;
      if (count < maxPerPlatform) {
        result.add(rec);
        platformSlots[rec.sourcePlatform] = count + 1;
      }
    }
    return result;
  }

  Future<String> _generateReason(Recommendation rec, ProfileSummary profile) async {
    try {
      final result = await _llm.chatJson(
        systemPrompt: LLMPrompts.systemBase,
        userPrompt: LLMPrompts.recommendReason(profile.toJson(), rec.toJson()),
        temperature: 0.5,
        maxTokens: 512,
      );
      if (result != null) {
        return result['reason']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<void> _recordImpression(Recommendation rec) async {
    final history = ContentHistoryItem(
      itemKey: rec.itemKey,
      sourcePlatform: rec.sourcePlatform,
      contentId: rec.contentId,
      contentUrl: rec.contentUrl,
      contentType: rec.contentType,
      title: rec.title,
      authorName: rec.upName,
      coverUrl: rec.coverUrl,
      historyType: 'impressed',
      eventAt: DateTime.now(),
      impressionCount: 1,
      recommendReason: rec.recommendReason,
      matchScore: rec.matchScore,
    );
    await _repo.upsertHistory(history);

    final event = BehaviorEvent(
      eventId: 'imp_${DateTime.now().millisecondsSinceEpoch}_${rec.contentId}',
      eventType: 'impression',
      sourcePlatform: rec.sourcePlatform,
      contentId: rec.contentId,
      title: rec.title,
      createdAt: DateTime.now(),
      weight: 0.3,
    );
    await _repo.insertEvent(event);
  }

  Future<void> recordClick(Recommendation rec) async {
    final history = ContentHistoryItem(
      itemKey: rec.itemKey,
      sourcePlatform: rec.sourcePlatform,
      contentId: rec.contentId,
      contentUrl: rec.contentUrl,
      contentType: rec.contentType,
      title: rec.title,
      authorName: rec.upName,
      coverUrl: rec.coverUrl,
      historyType: 'clicked',
      eventAt: DateTime.now(),
      clickCount: 1,
      recommendReason: rec.recommendReason,
      matchScore: rec.matchScore,
    );
    await _repo.upsertHistory(history);

    await _profileEngine.processFeedback(
      contentId: rec.contentId,
      title: rec.title,
      sourcePlatform: rec.sourcePlatform,
      feedbackType: 'click',
      contentMetadata: rec.toJson(),
    );
  }

  Future<void> recordFeedback(Recommendation rec, String feedbackType) async {
    await _repo.updateRecommendationFeedback(rec.itemKey, feedbackType);
    await _profileEngine.processFeedback(
      contentId: rec.contentId,
      title: rec.title,
      sourcePlatform: rec.sourcePlatform,
      feedbackType: feedbackType,
      contentMetadata: rec.toJson(),
    );
  }

  Future<DelightCard?> generateDelight() async {
    final profile = await _profileEngine.getProfile();
    if (!profile.initialized) return null;

    final candidates = await _repo.getRecommendations(limit: 50, minMatchScore: 0.3);
    if (candidates.isEmpty) return null;

    if (!_llm.isReady) {
      final speculative = candidates
          .where((r) => profile.speculativeInterests.any(
              (s) => r.title.toLowerCase().contains(s.domain.toLowerCase())))
          .toList();
      if (speculative.isEmpty) return null;
      final pick = speculative[_random.nextInt(speculative.length)];
      return DelightCard(
        delightId: 'delight_${DateTime.now().millisecondsSinceEpoch}',
        content: pick,
        reason: '基于你的探索倾向，试试这个新领域',
        bridgeLogic: '从已有兴趣到新领域的自然延伸',
        speculationDomain: pick.topicLabel,
        speculationConfidence: 0.5,
        challengeType: 'interest',
        createdAt: DateTime.now(),
      );
    }

    final result = await _llm.chatJson(
      systemPrompt: LLMPrompts.systemBase,
      userPrompt: LLMPrompts.delightGeneration(
        profile.toJson(),
        candidates.map((c) => c.toJson()).toList(),
      ),
      temperature: 0.7,
      maxTokens: 2048,
    );

    if (result == null) return null;
    final delights = (result['delights'] as List?) ?? [];
    if (delights.isEmpty) return null;

    final pick = Map<String, dynamic>.from(delights.first);
    final contentTitle = pick['content_title']?.toString() ?? '';
    final matched = candidates.firstWhere(
      (c) => c.title == contentTitle,
      orElse: () => candidates.first,
    );

    final card = DelightCard(
      delightId: 'delight_${DateTime.now().millisecondsSinceEpoch}',
      content: matched,
      reason: pick['reason']?.toString() ?? '',
      bridgeLogic: pick['bridge_logic']?.toString() ?? '',
      speculationDomain: pick['speculation_domain']?.toString() ?? '',
      speculationConfidence: (pick['speculation_confidence'] as num?)?.toDouble() ?? 0.5,
      challengeType: pick['challenge_type']?.toString() ?? 'interest',
      createdAt: DateTime.now(),
    );
    await _repo.insertDelight(card);
    return card;
  }

  Future<List<Recommendation>> search(String query, {int limit = 20}) async {
    final results = await _sources.searchAll(query, perSourceLimit: 10);
    final profile = await _profileEngine.getProfile();
    final scored = await _scoreAndRank(results, profile);
    return scored.take(limit).toList();
  }

  Future<List<Recommendation>> reshuffle({int limit = 20}) async {
    final candidates = await _repo.getRecommendations(limit: 100);
    final profile = await _profileEngine.getProfile();
    final scored = await _scoreAndRank(candidates, profile);

    final shuffled = <Recommendation>[];
    final highScore = scored.where((r) => r.matchScore > 0.6).toList();
    final midScore = scored.where((r) => r.matchScore >= 0.4 && r.matchScore <= 0.6).toList();
    final lowScore = scored.where((r) => r.matchScore < 0.4).toList();

    highScore.shuffle(_random);
    midScore.shuffle(_random);
    lowScore.shuffle(_random);

    shuffled.addAll(highScore.take(limit ~/ 2));
    shuffled.addAll(midScore.take(limit ~/ 4));
    shuffled.addAll(lowScore.take(limit ~/ 4));

    return shuffled.take(limit).toList();
  }
}
