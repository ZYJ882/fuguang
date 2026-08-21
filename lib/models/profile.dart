import '../utils/app_utils.dart';

class ProfileSummary {
  final String portrait;
  final List<ProfileLayer> layers;
  final List<String> deepNeeds;
  final ProfileMbti mbti;
  final List<String> values;
  final List<String> motivationalDrivers;
  final List<ProfileInterest> interests;
  final List<ProfileInterest> avoidances;
  final List<String> favoriteUpUsers;
  final String lifeStage;
  final String currentPhase;
  final List<String> cognitiveStyle;
  final ProfileStyle style;
  final ProfileContext context;
  final double explorationOpenness;
  final List<ProfileSpeculation> speculativeInterests;
  final List<ProfileSpeculation> speculativeAvoidances;
  final List<ProfileCognitionUpdate> cognitionUpdates;
  final List<ProfileInsight> activeInsights;
  final List<ProfileAwareness> recentAwareness;
  final Map<String, dynamic> overrides;
  final bool initialized;
  final DateTime? updatedAt;

  const ProfileSummary({
    this.portrait = '',
    this.layers = const [],
    this.deepNeeds = const [],
    this.mbti = const ProfileMbti(),
    this.values = const [],
    this.motivationalDrivers = const [],
    this.interests = const [],
    this.avoidances = const [],
    this.favoriteUpUsers = const [],
    this.lifeStage = '',
    this.currentPhase = '',
    this.cognitiveStyle = const [],
    this.style = const ProfileStyle(),
    this.context = const ProfileContext(),
    this.explorationOpenness = 0.5,
    this.speculativeInterests = const [],
    this.speculativeAvoidances = const [],
    this.cognitionUpdates = const [],
    this.activeInsights = const [],
    this.recentAwareness = const [],
    this.overrides = const {},
    this.initialized = false,
    this.updatedAt,
  });

  factory ProfileSummary.fromJson(Map<String, dynamic> json) => ProfileSummary(
    portrait: AppUtils.decodeHtml(json['portrait']?.toString() ?? ''),
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
    favoriteUpUsers:
        (json['favorite_up_users'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    lifeStage: json['life_stage']?.toString() ?? '',
    currentPhase: json['current_phase']?.toString() ?? '',
    cognitiveStyle:
        (json['cognitive_style'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    style: ProfileStyle.fromJson(
      json['style'] is Map ? Map<String, dynamic>.from(json['style']) : const {},
    ),
    context: ProfileContext.fromJson(
      json['context'] is Map ? Map<String, dynamic>.from(json['context']) : const {},
    ),
    explorationOpenness: (json['exploration_openness'] as num?)?.toDouble() ?? 0.5,
    speculativeInterests: (json['speculative_interests'] as List?)
            ?.map((e) => ProfileSpeculation.fromJson(Map<String, dynamic>.from(e), avoidance: false))
            .toList() ??
        const [],
    speculativeAvoidances: (json['speculative_avoidances'] as List?)
            ?.map((e) => ProfileSpeculation.fromJson(Map<String, dynamic>.from(e), avoidance: true))
            .toList() ??
        const [],
    cognitionUpdates: (json['recent_cognition_updates'] as List?)
            ?.map((e) => ProfileCognitionUpdate.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    activeInsights: (json['active_insights'] as List?)
            ?.map((e) => ProfileInsight.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    recentAwareness: (json['recent_awareness'] as List?)
            ?.map((e) => ProfileAwareness.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    overrides: json['overrides'] is Map ? Map<String, dynamic>.from(json['overrides']) : const {},
    initialized: json['initialized'] == true,
    updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
  );

  Map<String, dynamic> toJson() => {
    'portrait': portrait,
    'layers': layers.map((e) => e.toJson()).toList(),
    'deep_needs': deepNeeds,
    'mbti': mbti.toJson(),
    'values': values,
    'motivational_drivers': motivationalDrivers,
    'interests': interests.map((e) => e.toJson()).toList(),
    'avoidances': avoidances.map((e) => e.toJson()).toList(),
    'favorite_up_users': favoriteUpUsers,
    'life_stage': lifeStage,
    'current_phase': currentPhase,
    'cognitive_style': cognitiveStyle,
    'style': style.toJson(),
    'context': context.toJson(),
    'exploration_openness': explorationOpenness,
    'speculative_interests': speculativeInterests.map((e) => e.toJson()).toList(),
    'speculative_avoidances': speculativeAvoidances.map((e) => e.toJson()).toList(),
    'recent_cognition_updates': cognitionUpdates.map((e) => e.toJson()).toList(),
    'active_insights': activeInsights.map((e) => e.toJson()).toList(),
    'recent_awareness': recentAwareness.map((e) => e.toJson()).toList(),
    'overrides': overrides,
    'initialized': initialized,
    'updated_at': updatedAt?.toIso8601String(),
  };

  bool get hasContent =>
      portrait.isNotEmpty || layers.isNotEmpty || interests.isNotEmpty || avoidances.isNotEmpty;
}

class ProfileLayer {
  final String name;
  final String summary;
  final double weight;
  final String level; // event, preference, awareness, insight, soul

  const ProfileLayer({
    required this.name,
    this.summary = '',
    this.weight = 0,
    this.level = 'preference',
  });

  factory ProfileLayer.fromJson(Map<String, dynamic> json) => ProfileLayer(
    name: AppUtils.decodeHtml(json['name']?.toString() ?? json['trait']?.toString() ?? ''),
    summary: AppUtils.decodeHtml(json['summary']?.toString() ?? ''),
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    level: json['level']?.toString() ?? 'preference',
  );

  Map<String, dynamic> toJson() => {'name': name, 'summary': summary, 'weight': weight, 'level': level};
}

class ProfileInterest {
  final String name;
  final double weight;
  final String category;
  final String reason;
  final List<String> specifics;
  final int interactionCount;

  const ProfileInterest({
    this.name = '',
    this.weight = 0,
    this.category = '',
    this.reason = '',
    this.specifics = const [],
    this.interactionCount = 0,
  });

  factory ProfileInterest.fromJson(Map<String, dynamic> json) => ProfileInterest(
    name: AppUtils.decodeHtml(json['name']?.toString() ?? json['domain']?.toString() ?? ''),
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    category: json['category']?.toString() ?? json['domain']?.toString() ?? '',
    reason: AppUtils.decodeHtml(json['reason']?.toString() ?? ''),
    specifics: (json['specifics'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    interactionCount: (json['interaction_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'weight': weight,
    'category': category,
    'reason': reason,
    'specifics': specifics,
    'interaction_count': interactionCount,
  };
}

class ProfileMbti {
  final String type;
  final double confidence;
  final Map<String, ProfileMbtiDimension> dimensions;

  const ProfileMbti({this.type = '', this.confidence = 0, this.dimensions = const {}});

  factory ProfileMbti.fromJson(Map<String, dynamic> json) {
    final dims = json['dimensions'] is Map ? Map<String, dynamic>.from(json['dimensions']) : const {};
    return ProfileMbti(
      type: json['type']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      dimensions: dims.map((k, v) => MapEntry(
        k,
        ProfileMbtiDimension.fromJson(v is Map ? Map<String, dynamic>.from(v) : const {}),
      )),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'confidence': confidence,
    'dimensions': dimensions.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class ProfileMbtiDimension {
  final String pole;
  final double strength;
  const ProfileMbtiDimension({this.pole = '', this.strength = 0});
  factory ProfileMbtiDimension.fromJson(Map<String, dynamic> json) => ProfileMbtiDimension(
    pole: json['pole']?.toString() ?? '',
    strength: (json['strength'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {'pole': pole, 'strength': strength};
}

class ProfileStyle {
  final String preferredDuration;
  final String preferredPace;
  final double qualitySensitivity;
  final double humorPreference;
  final double depthPreference;
  const ProfileStyle({
    this.preferredDuration = '',
    this.preferredPace = '',
    this.qualitySensitivity = 0.5,
    this.humorPreference = 0.5,
    this.depthPreference = 0.5,
  });
  factory ProfileStyle.fromJson(Map<String, dynamic> json) => ProfileStyle(
    preferredDuration: json['preferred_duration']?.toString() ?? '',
    preferredPace: json['preferred_pace']?.toString() ?? '',
    qualitySensitivity: (json['quality_sensitivity'] as num?)?.toDouble() ?? 0.5,
    humorPreference: (json['humor_preference'] as num?)?.toDouble() ?? 0.5,
    depthPreference: (json['depth_preference'] as num?)?.toDouble() ?? 0.5,
  );
  Map<String, dynamic> toJson() => {
    'preferred_duration': preferredDuration,
    'preferred_pace': preferredPace,
    'quality_sensitivity': qualitySensitivity,
    'humor_preference': humorPreference,
    'depth_preference': depthPreference,
  };
}

class ProfileContext {
  final String weekdayPatterns;
  final String weekendPatterns;
  final String timeOfDayPatterns;
  final String sessionType;
  const ProfileContext({
    this.weekdayPatterns = '',
    this.weekendPatterns = '',
    this.timeOfDayPatterns = '',
    this.sessionType = '',
  });
  factory ProfileContext.fromJson(Map<String, dynamic> json) => ProfileContext(
    weekdayPatterns: json['weekday_patterns']?.toString() ?? '',
    weekendPatterns: json['weekend_patterns']?.toString() ?? '',
    timeOfDayPatterns: json['time_of_day_patterns']?.toString() ?? '',
    sessionType: json['session_type']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {
    'weekday_patterns': weekdayPatterns,
    'weekend_patterns': weekendPatterns,
    'time_of_day_patterns': timeOfDayPatterns,
    'session_type': sessionType,
  };
}

class ProfileSpeculation {
  final String domain;
  final String reason;
  final double confidence;
  final String probeMode;
  final bool challenge;
  final int confirmationCount;
  final int confirmationThreshold;
  final List<String> specifics;
  final bool avoidance;
  final String status; // probing, confirmed, rejected, dormant

  const ProfileSpeculation({
    required this.domain,
    this.reason = '',
    this.confidence = 0,
    this.probeMode = '',
    this.challenge = false,
    this.confirmationCount = 0,
    this.confirmationThreshold = 3,
    this.specifics = const [],
    this.avoidance = false,
    this.status = 'probing',
  });

  factory ProfileSpeculation.fromJson(Map<String, dynamic> json, {required bool avoidance}) =>
      ProfileSpeculation(
        domain: AppUtils.decodeHtml(json['domain']?.toString() ?? ''),
        reason: AppUtils.decodeHtml(json['reason']?.toString() ?? ''),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        probeMode: json['probe_mode']?.toString() ?? json['source_mode']?.toString() ?? '',
        challenge: json['challenge'] == true,
        confirmationCount: (json['confirmation_count'] as num?)?.toInt() ?? 0,
        confirmationThreshold: (json['confirmation_threshold'] as num?)?.toInt() ?? 3,
        specifics: (json['specifics'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        avoidance: avoidance,
        status: json['status']?.toString() ?? 'probing',
      );

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'reason': reason,
    'confidence': confidence,
    'probe_mode': probeMode,
    'challenge': challenge,
    'confirmation_count': confirmationCount,
    'confirmation_threshold': confirmationThreshold,
    'specifics': specifics,
    'status': status,
  };
}

class ProfileCognitionUpdate {
  final String summary;
  final String contextLine;
  final String impact;
  final String reasoning;
  final String evidence;
  final String sourceLabel;
  final String createdAt;
  final bool seen;

  const ProfileCognitionUpdate({
    this.summary = '',
    this.contextLine = '',
    this.impact = '',
    this.reasoning = '',
    this.evidence = '',
    this.sourceLabel = '',
    this.createdAt = '',
    this.seen = false,
  });

  factory ProfileCognitionUpdate.fromJson(Map<String, dynamic> json) => ProfileCognitionUpdate(
    summary: AppUtils.decodeHtml(json['summary']?.toString() ?? ''),
    contextLine: AppUtils.decodeHtml(json['context_line']?.toString() ?? ''),
    impact: AppUtils.decodeHtml(json['impact']?.toString() ?? ''),
    reasoning: AppUtils.decodeHtml(json['reasoning']?.toString() ?? ''),
    evidence: AppUtils.decodeHtml(json['evidence']?.toString() ?? ''),
    sourceLabel: json['source_label']?.toString() ?? json['source']?.toString() ?? '',
    createdAt: json['created_at']?.toString() ?? '',
    seen: json['seen'] == true,
  );

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'context_line': contextLine,
    'impact': impact,
    'reasoning': reasoning,
    'evidence': evidence,
    'source_label': sourceLabel,
    'created_at': createdAt,
    'seen': seen,
  };
}

class ProfileInsight {
  final String hypothesis;
  final List<String> evidence;
  final double confidence;
  final bool validated;
  final String createdAt;
  const ProfileInsight({
    this.hypothesis = '',
    this.evidence = const [],
    this.confidence = 0,
    this.validated = false,
    this.createdAt = '',
  });
  factory ProfileInsight.fromJson(Map<String, dynamic> json) => ProfileInsight(
    hypothesis: AppUtils.decodeHtml(json['hypothesis']?.toString() ?? ''),
    evidence: (json['evidence'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    validated: json['validated'] == true,
    createdAt: json['created_at']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {
    'hypothesis': hypothesis,
    'evidence': evidence,
    'confidence': confidence,
    'validated': validated,
    'created_at': createdAt,
  };
}

class ProfileAwareness {
  final String date;
  final String observation;
  final String trend;
  final String emotionGuess;
  const ProfileAwareness({
    this.date = '',
    this.observation = '',
    this.trend = '',
    this.emotionGuess = '',
  });
  factory ProfileAwareness.fromJson(Map<String, dynamic> json) => ProfileAwareness(
    date: json['date']?.toString() ?? '',
    observation: AppUtils.decodeHtml(json['observation']?.toString() ?? ''),
    trend: AppUtils.decodeHtml(json['trend']?.toString() ?? ''),
    emotionGuess: AppUtils.decodeHtml(json['emotion_guess']?.toString() ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'date': date,
    'observation': observation,
    'trend': trend,
    'emotion_guess': emotionGuess,
  };
}
