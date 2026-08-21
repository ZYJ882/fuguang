import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recommendation.dart';
import '../utils/app_utils.dart';
import '../services/content_launcher.dart';

class RecommendationCard extends StatelessWidget {
  final Recommendation rec;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onWatchLater;
  final VoidCallback? onFavorite;
  final VoidCallback? onChat;
  final bool showFeedback;

  const RecommendationCard({
    super.key,
    required this.rec,
    this.onLike,
    this.onDislike,
    this.onWatchLater,
    this.onFavorite,
    this.onChat,
    this.showFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ContentLauncher.openContent(rec),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!rec.isTextCard && rec.coverUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: rec.coverUrl,
                        width: 120,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 120,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 120,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.displayUpName,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _PlatformBadge(platform: rec.sourcePlatform),
                            if (rec.statsLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rec.statsLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (rec.recommendReason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rec.recommendReason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (showFeedback) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _FeedbackButton(
                      icon: Icons.thumb_up_outlined,
                      label: '喜欢',
                      active: rec.feedbackType == 'like',
                      onTap: onLike,
                    ),
                    _FeedbackButton(
                      icon: Icons.watch_later_outlined,
                      label: '稍后',
                      onTap: onWatchLater,
                    ),
                    _FeedbackButton(
                      icon: Icons.star_border,
                      label: '收藏',
                      onTap: onFavorite,
                    ),
                    _FeedbackButton(
                      icon: Icons.chat_bubble_outline,
                      label: '聊聊',
                      onTap: onChat,
                    ),
                    _FeedbackButton(
                      icon: Icons.thumb_down_off_alt_outlined,
                      label: '不感兴趣',
                      active: rec.feedbackType == 'dislike',
                      onTap: onDislike,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  final String platform;
  const _PlatformBadge({required this.platform});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'bilibili': const Color(0xFFFB7299),
      'xiaohongshu': const Color(0xFFFF2442),
      'douyin': const Color(0xFF000000),
      'zhihu': const Color(0xFF0066FF),
      'youtube': const Color(0xFFFF0000),
      'twitter': const Color(0xFF1DA1F2),
      'reddit': const Color(0xFFFF4500),
      'weibo': const Color(0xFFFF6600),
      'web': Colors.grey,
    };
    final color = colors[platform] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        SourcePlatform.label(platform),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _FeedbackButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(width: 120, height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 150, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DelightCardWidget extends StatelessWidget {
  final dynamic delight;
  final VoidCallback? onView;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onDismiss;

  const DelightCardWidget({
    super.key,
    required this.delight,
    this.onView,
    this.onLike,
    this.onDislike,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.secondary.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 6),
              Text('惊喜推荐', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              const Spacer(),
              if (delight.speculationConfidence > 0)
                Text('${(delight.speculationConfidence * 100).toInt()}% 匹配', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(delight.content.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          if (delight.reason.isNotEmpty)
            Text(delight.reason, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          if (delight.bridgeLogic.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.psychology, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(delight.bridgeLogic, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: onView, icon: const Icon(Icons.visibility), label: const Text('看看'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)))),
              const SizedBox(width: 8),
              IconButton(onPressed: onLike, icon: const Icon(Icons.favorite_border), tooltip: '喜欢'),
              IconButton(onPressed: onDislike, icon: const Icon(Icons.close), tooltip: '不感兴趣'),
            ],
          ),
        ],
      ),
    );
  }
}
