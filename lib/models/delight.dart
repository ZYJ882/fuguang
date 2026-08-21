import '../utils/app_utils.dart';
import 'recommendation.dart';

class DelightCard {
  final String delightId;
  final Recommendation content;
  final String reason;
  final String bridgeLogic; // 心理学桥接逻辑说明
  final String speculationDomain;
  final double speculationConfidence;
  final String challengeType; // interest, avoidance, perspective
  final DateTime createdAt;
  final String status; // pending, liked, disliked, dismissed, discussed
  final int ackCount;

  const DelightCard({
    required this.delightId,
    required this.content,
    this.reason = '',
    this.bridgeLogic = '',
    this.speculationDomain = '',
    this.speculationConfidence = 0,
    this.challengeType = 'interest',
    required this.createdAt,
    this.status = 'pending',
    this.ackCount = 0,
  });

  factory DelightCard.fromJson(Map<String, dynamic> json) => DelightCard(
        delightId:
            json['delight_id']?.toString() ?? json['id']?.toString() ?? '',
        content: Recommendation.fromJson(
          json['content'] is Map
              ? Map<String, dynamic>.from(json['content'])
              : const {},
        ),
        reason: AppUtils.decodeHtml(json['reason']?.toString() ?? ''),
        bridgeLogic:
            AppUtils.decodeHtml(json['bridge_logic']?.toString() ?? ''),
        speculationDomain: json['speculation_domain']?.toString() ?? '',
        speculationConfidence:
            (json['speculation_confidence'] as num?)?.toDouble() ?? 0,
        challengeType: json['challenge_type']?.toString() ?? 'interest',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        status: json['status']?.toString() ?? 'pending',
        ackCount: (json['ack_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'delight_id': delightId,
        'content': content.toJson(),
        'reason': reason,
        'bridge_logic': bridgeLogic,
        'speculation_domain': speculationDomain,
        'speculation_confidence': speculationConfidence,
        'challenge_type': challengeType,
        'created_at': createdAt.toIso8601String(),
        'status': status,
        'ack_count': ackCount,
      };
}

class RuntimeStatus {
  final bool healthy;
  final String version;
  final DateTime startTime;
  final int totalEvents;
  final int recommendationPoolSize;
  final int savedCount;
  final int profileEventCount;
  final bool llmReady;
  final bool embeddingReady;
  final String llmProvider;
  final String llmModel;
  final List<String> activeSources;
  final Map<String, dynamic> sourceStatus;
  final int pendingNotifications;
  final double llmBudgetUsed;
  final double llmBudgetTotal;

  const RuntimeStatus({
    this.healthy = false,
    this.version = '1.0.7',
    required this.startTime,
    this.totalEvents = 0,
    this.recommendationPoolSize = 0,
    this.savedCount = 0,
    this.profileEventCount = 0,
    this.llmReady = false,
    this.embeddingReady = false,
    this.llmProvider = '',
    this.llmModel = '',
    this.activeSources = const [],
    this.sourceStatus = const {},
    this.pendingNotifications = 0,
    this.llmBudgetUsed = 0,
    this.llmBudgetTotal = 0,
  });

  factory RuntimeStatus.fromJson(Map<String, dynamic> json) => RuntimeStatus(
        healthy: json['healthy'] == true,
        version: json['version']?.toString() ?? '1.0.7',
        startTime: DateTime.tryParse(json['start_time']?.toString() ?? '') ??
            DateTime.now(),
        totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
        recommendationPoolSize:
            (json['recommendation_pool_size'] as num?)?.toInt() ?? 0,
        savedCount: (json['saved_count'] as num?)?.toInt() ?? 0,
        profileEventCount: (json['profile_event_count'] as num?)?.toInt() ?? 0,
        llmReady: json['llm_ready'] == true,
        embeddingReady: json['embedding_ready'] == true,
        llmProvider: json['llm_provider']?.toString() ?? '',
        llmModel: json['llm_model']?.toString() ?? '',
        activeSources: (json['active_sources'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        sourceStatus: json['source_status'] is Map
            ? Map<String, dynamic>.from(json['source_status'])
            : const {},
        pendingNotifications:
            (json['pending_notifications'] as num?)?.toInt() ?? 0,
        llmBudgetUsed: (json['llm_budget_used'] as num?)?.toDouble() ?? 0,
        llmBudgetTotal: (json['llm_budget_total'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'healthy': healthy,
        'version': version,
        'start_time': startTime.toIso8601String(),
        'total_events': totalEvents,
        'recommendation_pool_size': recommendationPoolSize,
        'saved_count': savedCount,
        'profile_event_count': profileEventCount,
        'llm_ready': llmReady,
        'embedding_ready': embeddingReady,
        'llm_provider': llmProvider,
        'llm_model': llmModel,
        'active_sources': activeSources,
        'source_status': sourceStatus,
        'pending_notifications': pendingNotifications,
        'llm_budget_used': llmBudgetUsed,
        'llm_budget_total': llmBudgetTotal,
      };

  String get uptime {
    final diff = DateTime.now().difference(startTime);
    if (diff.inDays > 0) return '${diff.inDays}天${diff.inHours % 24}小时';
    if (diff.inHours > 0) return '${diff.inHours}小时${diff.inMinutes % 60}分钟';
    return '${diff.inMinutes}分钟';
  }
}

class BehaviorEvent {
  final String eventId;
  final String eventType; // view, click, like, dislike, feedback, save, chat
  final String sourcePlatform;
  final String contentId;
  final String contentUrl;
  final String title;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final double weight;

  const BehaviorEvent({
    required this.eventId,
    required this.eventType,
    this.sourcePlatform = '',
    this.contentId = '',
    this.contentUrl = '',
    this.title = '',
    this.metadata = const {},
    required this.createdAt,
    this.weight = 1.0,
  });

  factory BehaviorEvent.fromJson(Map<String, dynamic> json) => BehaviorEvent(
        eventId: json['event_id']?.toString() ?? '',
        eventType: json['event_type']?.toString() ?? '',
        sourcePlatform: json['source_platform']?.toString() ?? '',
        contentId: json['content_id']?.toString() ?? '',
        contentUrl: json['content_url']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'])
            : const {},
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'event_type': eventType,
        'source_platform': sourcePlatform,
        'content_id': contentId,
        'content_url': contentUrl,
        'title': title,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
        'weight': weight,
      };
}
