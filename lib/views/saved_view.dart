import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_providers.dart';
import '../models/saved_item.dart';
import '../services/content_launcher.dart';
import '../utils/app_utils.dart';

class SavedView extends StatefulWidget {
  const SavedView({super.key});

  @override
  State<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends State<SavedView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavedProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('内容库'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '稍后再看 (${provider.watchLater.length})'),
            Tab(text: '我的收藏 (${provider.favorites.length})'),
            const Tab(text: '历史记录'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSavedList(provider.watchLater, 'watch_later', theme, provider),
                _buildSavedList(provider.favorites, 'favorite', theme, provider),
                _buildHistoryList(provider.history, theme),
              ],
            ),
    );
  }

  Widget _buildSavedList(List<SavedItem> items, String kind, ThemeData theme, SavedProvider provider) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(kind == 'watch_later' ? Icons.watch_later_outlined : Icons.star_border, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(kind == 'watch_later' ? '还没有稍后再看的内容' : '还没有收藏内容', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('在推荐页点击「稍后」或「收藏」添加内容', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ContentLauncher.openUrl(item.contentUrl),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.coverUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item.coverUrl,
                        width: 100,
                        height: 70,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                      ),
                    )
                  else
                    Container(width: 100, height: 70, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.article, color: Colors.grey)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(item.authorName, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _PlatformBadge(platform: item.sourcePlatform),
                            const SizedBox(width: 8),
                            Text(_formatTime(item.savedAt), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'remove') {
                        if (kind == 'watch_later') provider.removeFromWatchLater(item.itemKey);
                        else provider.removeFromFavorites(item.itemKey);
                      } else if (action == 'move') {
                        if (kind == 'watch_later') {
                          provider.removeFromWatchLater(item.itemKey);
                        } else {
                          provider.removeFromFavorites(item.itemKey);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'move', child: Text(kind == 'watch_later' ? '移到收藏' : '移到稍后再看')),
                      const PopupMenuItem(value: 'remove', child: Text('移除')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(List<ContentHistoryItem> items, ThemeData theme) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('暂无浏览历史', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ContentLauncher.openUrl(item.contentUrl),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (item.coverUrl.isNotEmpty)
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item.coverUrl, width: 80, height: 60, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 80, height: 60, color: Colors.grey.shade200)))
                  else
                    Container(width: 80, height: 60, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.article, color: Colors.grey, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _PlatformBadge(platform: item.sourcePlatform),
                            const SizedBox(width: 8),
                            Text(_formatTime(item.eventAt), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            const SizedBox(width: 8),
                            _HistoryTypeBadge(type: item.historyType),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }
}

class _PlatformBadge extends StatelessWidget {
  final String platform;
  const _PlatformBadge({required this.platform});

  @override
  Widget build(BuildContext context) {
    final colors = {'bilibili': const Color(0xFFFB7299), 'xiaohongshu': const Color(0xFFFF2442), 'douyin': Colors.black, 'zhihu': const Color(0xFF0066FF), 'web': Colors.grey};
    final color = colors[platform] ?? Colors.grey;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(SourcePlatform.label(platform), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)));
  }
}

class _HistoryTypeBadge extends StatelessWidget {
  final String type;
  const _HistoryTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final labels = {'clicked': '已点开', 'impressed': '出现过', 'removed': '已移除'};
    final colors = {'clicked': Colors.green, 'impressed': Colors.grey, 'removed': Colors.red};
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (colors[type] ?? Colors.grey).withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(labels[type] ?? type, style: TextStyle(fontSize: 10, color: colors[type] ?? Colors.grey)));
  }
}
