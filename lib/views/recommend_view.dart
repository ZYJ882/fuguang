import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../widgets/recommendation_card.dart';
import '../models/recommendation.dart';

class RecommendView extends StatefulWidget {
  const RecommendView({super.key});

  @override
  State<RecommendView> createState() => _RecommendViewState();
}

class _RecommendViewState extends State<RecommendView> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 400 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecommendProvider>().loadRecommendations();
      context.read<RecommendProvider>().loadDelight();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<RecommendProvider>().loadRecommendations(forceRefresh: true);
    await context.read<RecommendProvider>().loadDelight();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecommendProvider>();
    final savedProvider = context.watch<SavedProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('为你推荐'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: '换一批',
            onPressed: provider.isLoading ? null : () => provider.reshuffle(),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: provider.isLoading && provider.recommendations.isEmpty
            ? ListView.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const SkeletonCard(),
              )
            : provider.recommendations.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: provider.recommendations.length + (provider.delight != null ? 1 : 0) + 1,
                    itemBuilder: (context, index) {
                      if (index == 0 && provider.delight != null) {
                        return DelightCardWidget(
                          delight: provider.delight!,
                          onView: () => provider.ackDelight(provider.delight!.delightId, 'viewed'),
                          onLike: () => provider.ackDelight(provider.delight!.delightId, 'liked'),
                          onDislike: () => provider.ackDelight(provider.delight!.delightId, 'disliked'),
                        );
                      }
                      final recIndex = provider.delight != null ? index - 1 : index;
                      if (recIndex >= provider.recommendations.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('已经到底啦，下拉刷新更多')),
                        );
                      }
                      final rec = provider.recommendations[recIndex];
                      return RecommendationCard(
                        rec: rec,
                        onLike: () => provider.recordFeedback(rec, 'like'),
                        onDislike: () => provider.recordFeedback(rec, 'dislike'),
                        onWatchLater: () => savedProvider.addToWatchLater(rec),
                        onFavorite: () => savedProvider.addToFavorites(rec),
                        onChat: () => _openChatAbout(context, rec),
                      );
                    },
                  ),
      ),
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              mini: true,
              onPressed: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(Icons.explore_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text('正在为你探索内容', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('首次加载需要一些时间，请稍候...', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _onRefresh, child: const Text('重新加载')),
            ],
          ),
        ),
      ],
    );
  }

  void _openChatAbout(BuildContext context, Recommendation rec) {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.sendMessage('我想聊聊「${rec.title}」，你觉得这个内容怎么样？');
    DefaultTabController.of(context).animateTo(2);
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _ContentSearchDelegate(),
    );
  }
}

class _ContentSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text('输入关键词搜索内容'));
    return FutureBuilder<List<Recommendation>>(
      future: context.read<RecommendProvider>().search(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final results = snapshot.data!;
        if (results.isEmpty) return const Center(child: Text('没有找到相关内容'));
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) => RecommendationCard(rec: results[index], showFeedback: false),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = ['科技', '游戏', '音乐', '美食', '旅行', '电影', '健身', '知识'];
    return ListView(
      children: suggestions.where((s) => s.contains(query)).map((s) => ListTile(
        leading: const Icon(Icons.search),
        title: Text(s),
        onTap: () { query = s; showResults(context); },
      )).toList(),
    );
  }
}
