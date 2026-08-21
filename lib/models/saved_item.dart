import '../utils/app_utils.dart';

class SavedItem {
  final String itemKey;
  final String sourcePlatform;
  final String contentId;
  final String contentUrl;
  final String contentType;
  final String title;
  final String authorName;
  final String coverUrl;
  final String note;
  final String listKind; // watch_later, favorite
  final DateTime savedAt;
  final DateTime? updatedAt;
  final String feedbackType;
  final bool syncedToPlatform;

  const SavedItem({
    required this.itemKey,
    this.sourcePlatform = 'bilibili',
    this.contentId = '',
    this.contentUrl = '',
    this.contentType = 'video',
    this.title = '',
    this.authorName = '',
    this.coverUrl = '',
    this.note = '',
    required this.listKind,
    required this.savedAt,
    this.updatedAt,
    this.feedbackType = '',
    this.syncedToPlatform = false,
  });

  factory SavedItem.fromJson(Map<String, dynamic> json) => SavedItem(
    itemKey: json['item_key']?.toString() ?? '',
    sourcePlatform: SourcePlatform.normalize(
      json['source_platform']?.toString() ?? '',
      contentUrl: json['content_url']?.toString() ?? '',
    ),
    contentId: json['content_id']?.toString() ?? '',
    contentUrl: json['content_url']?.toString() ?? '',
    contentType: json['content_type']?.toString() ?? 'video',
    title: AppUtils.decodeHtml(json['title']?.toString() ?? ''),
    authorName: AppUtils.decodeHtml(json['author_name']?.toString() ?? json['up_name']?.toString() ?? ''),
    coverUrl: json['cover_url']?.toString() ?? '',
    note: json['note']?.toString() ?? '',
    listKind: json['list_kind']?.toString() ?? 'watch_later',
    savedAt: DateTime.tryParse(json['saved_at']?.toString() ?? '') ?? DateTime.now(),
    updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    feedbackType: json['feedback_type']?.toString() ?? '',
    syncedToPlatform: json['synced_to_platform'] == true,
  );

  Map<String, dynamic> toJson() => {
    'item_key': itemKey,
    'source_platform': sourcePlatform,
    'content_id': contentId,
    'content_url': contentUrl,
    'content_type': contentType,
    'title': title,
    'author_name': authorName,
    'cover_url': coverUrl,
    'note': note,
    'list_kind': listKind,
    'saved_at': savedAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'feedback_type': feedbackType,
    'synced_to_platform': syncedToPlatform,
  };

  String get sourceLabel => SourcePlatform.label(sourcePlatform);
  String get displayTitle => title.isNotEmpty ? title : '未命名内容';
}

class ContentHistoryItem {
  final String itemKey;
  final String sourcePlatform;
  final String contentId;
  final String contentUrl;
  final String contentType;
  final String title;
  final String authorName;
  final String coverUrl;
  final String historyType; // clicked, impressed, removed
  final DateTime eventAt;
  final int impressionCount;
  final int clickCount;
  final String feedbackType;
  final String recommendReason;
  final double matchScore;

  const ContentHistoryItem({
    required this.itemKey,
    this.sourcePlatform = 'bilibili',
    this.contentId = '',
    this.contentUrl = '',
    this.contentType = 'video',
    this.title = '',
    this.authorName = '',
    this.coverUrl = '',
    required this.historyType,
    required this.eventAt,
    this.impressionCount = 0,
    this.clickCount = 0,
    this.feedbackType = '',
    this.recommendReason = '',
    this.matchScore = 0,
  });

  factory ContentHistoryItem.fromJson(Map<String, dynamic> json) => ContentHistoryItem(
    itemKey: json['item_key']?.toString() ?? '',
    sourcePlatform: SourcePlatform.normalize(
      json['source_platform']?.toString() ?? '',
      contentUrl: json['content_url']?.toString() ?? '',
    ),
    contentId: json['content_id']?.toString() ?? '',
    contentUrl: json['content_url']?.toString() ?? '',
    contentType: json['content_type']?.toString() ?? 'video',
    title: AppUtils.decodeHtml(json['title']?.toString() ?? ''),
    authorName: AppUtils.decodeHtml(json['author_name']?.toString() ?? ''),
    coverUrl: json['cover_url']?.toString() ?? '',
    historyType: json['history_type']?.toString() ?? 'impressed',
    eventAt: DateTime.tryParse(json['event_at']?.toString() ?? '') ?? DateTime.now(),
    impressionCount: (json['impression_count'] as num?)?.toInt() ?? 0,
    clickCount: (json['click_count'] as num?)?.toInt() ?? 0,
    feedbackType: json['feedback_type']?.toString() ?? '',
    recommendReason: AppUtils.decodeHtml(json['recommend_reason']?.toString() ?? ''),
    matchScore: (json['match_score'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'item_key': itemKey,
    'source_platform': sourcePlatform,
    'content_id': contentId,
    'content_url': contentUrl,
    'content_type': contentType,
    'title': title,
    'author_name': authorName,
    'cover_url': coverUrl,
    'history_type': historyType,
    'event_at': eventAt.toIso8601String(),
    'impression_count': impressionCount,
    'click_count': clickCount,
    'feedback_type': feedbackType,
    'recommend_reason': recommendReason,
    'match_score': matchScore,
  };

  String get sourceLabel => SourcePlatform.label(sourcePlatform);
}
