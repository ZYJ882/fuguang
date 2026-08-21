import '../utils/app_utils.dart';

class Recommendation {
  final int id;
  final String bvid;
  final String itemKey;
  final String contentId;
  final String title;
  final String upName;
  final String coverUrl;
  final String expression;
  final String topicLabel;
  final String contentUrl;
  final String sourcePlatform;
  final String contentType;
  final String bodyText;
  final String publishedAt;
  final String publishedLabel;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final int danmakuCount;
  final int shareCount;
  final double ratingScore;
  final int ratingCount;
  final int sourceRank;
  final int duration;
  final List<String> tags;
  String feedbackType;
  final double matchScore;
  final String recommendReason;

  Recommendation({
    this.id = 0,
    required this.bvid,
    this.itemKey = '',
    this.contentId = '',
    this.title = '',
    this.upName = '',
    this.coverUrl = '',
    this.expression = '',
    this.topicLabel = '',
    this.contentUrl = '',
    this.sourcePlatform = 'bilibili',
    this.contentType = 'video',
    this.bodyText = '',
    this.publishedAt = '',
    this.publishedLabel = '',
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.favoriteCount = 0,
    this.danmakuCount = 0,
    this.shareCount = 0,
    this.ratingScore = 0,
    this.ratingCount = 0,
    this.sourceRank = 0,
    this.duration = 0,
    this.tags = const [],
    this.feedbackType = '',
    this.matchScore = 0,
    this.recommendReason = '',
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final bvid = json['bvid']?.toString() ?? '';
    final source = SourcePlatform.normalize(
      json['source_platform']?.toString() ?? '',
      contentUrl: json['content_url']?.toString() ?? '',
      bvid: bvid,
    );
    final explicitContentId = json['content_id']?.toString() ?? '';
    final contentId = explicitContentId.isNotEmpty
        ? explicitContentId
        : (bvid.contains(':') ? bvid.split(':').skip(1).join(':') : bvid);
    return Recommendation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bvid: bvid,
      itemKey: (json['item_key']?.toString() ?? '').isNotEmpty
          ? json['item_key'].toString()
          : (contentId.isEmpty ? '' : '$source:$contentId'),
      contentId: contentId,
      title: AppUtils.decodeHtml(json['title']?.toString() ?? ''),
      upName: AppUtils.decodeHtml(json['up_name']?.toString() ?? ''),
      coverUrl: json['cover_url']?.toString() ?? '',
      expression: AppUtils.decodeHtml(json['expression']?.toString() ?? ''),
      topicLabel: AppUtils.decodeHtml(json['topic_label']?.toString() ?? ''),
      contentUrl: json['content_url']?.toString() ?? '',
      sourcePlatform: source,
      contentType: (json['content_type']?.toString() ?? '').isNotEmpty
          ? json['content_type'].toString()
          : 'video',
      bodyText: AppUtils.decodeHtml(json['body_text']?.toString() ?? ''),
      publishedAt: json['published_at']?.toString() ?? '',
      publishedLabel: json['published_label']?.toString() ?? '',
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      danmakuCount: (json['danmaku_count'] as num?)?.toInt() ?? 0,
      shareCount: (json['share_count'] as num?)?.toInt() ?? 0,
      ratingScore: (json['rating_score'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      sourceRank: (json['source_rank'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      tags: AppUtils.parseTags(json['tags']?.toString()),
      feedbackType: json['feedback_type']?.toString() ?? '',
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0,
      recommendReason: AppUtils.decodeHtml(json['recommend_reason']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bvid': bvid,
    'item_key': itemKey,
    'content_id': contentId,
    'title': title,
    'up_name': upName,
    'cover_url': coverUrl,
    'expression': expression,
    'topic_label': topicLabel,
    'content_url': contentUrl,
    'source_platform': sourcePlatform,
    'content_type': contentType,
    'body_text': bodyText,
    'published_at': publishedAt,
    'published_label': publishedLabel,
    'view_count': viewCount,
    'like_count': likeCount,
    'comment_count': commentCount,
    'favorite_count': favoriteCount,
    'danmaku_count': danmakuCount,
    'share_count': shareCount,
    'rating_score': ratingScore,
    'rating_count': ratingCount,
    'source_rank': sourceRank,
    'duration': duration,
    'tags': tags.join(','),
    'feedback_type': feedbackType,
    'match_score': matchScore,
    'recommend_reason': recommendReason,
  };

  String get displayTitle => title.isNotEmpty ? title : '这条标题还没对上号';
  String get displayUpName => upName.isNotEmpty ? upName : '这位 UP 还没认出来';
  String get sourceLabel => SourcePlatform.label(sourcePlatform);

  bool get isTextCard =>
      coverUrl.isEmpty ||
      const {'tweet', 'thread', 'answer', 'article', 'question', 'post', 'comment'}
          .contains(contentType.toLowerCase());

  String get savedIdentity {
    if (itemKey.isNotEmpty) return itemKey;
    if (contentId.isNotEmpty) return '$sourcePlatform:$contentId';
    if (bvid.isNotEmpty) return '$sourcePlatform:$bvid';
    return contentUrl;
  }

  String get statsLabel {
    final parts = <String>[];
    if (viewCount > 0) parts.add('▶ ${AppUtils.formatCount(viewCount)}');
    if (likeCount > 0) parts.add('👍 ${AppUtils.formatCount(likeCount)}');
    if (commentCount > 0) parts.add('💬 ${AppUtils.formatCount(commentCount)}');
    if (favoriteCount > 0) parts.add('⭐ ${AppUtils.formatCount(favoriteCount)}');
    if (danmakuCount > 0) parts.add('弹幕 ${AppUtils.formatCount(danmakuCount)}');
    if (ratingScore > 0) parts.add('评分 ${ratingScore.toStringAsFixed(1)}');
    return parts.join(' · ');
  }

  String get publishedDisplay => AppUtils.formatTimeAgo(publishedAt.isEmpty ? null : publishedAt);

  Map<String, dynamic> toSavedPayload() => {
    'source_platform': sourcePlatform,
    'content_id': contentId,
    'content_url': contentUrl,
    'content_type': contentType,
    'title': title,
    'author_name': upName,
    'cover_url': coverUrl,
    'note': '',
  };
}
