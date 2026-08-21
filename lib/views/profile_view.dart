import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../models/profile.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('灵魂画像'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新生成画像',
            onPressed: provider.isLoading ? null : () => provider.regenerateProfile(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '人格素描'),
            Tab(text: '核心特质'),
            Tab(text: '兴趣偏好'),
            Tab(text: '认知更新'),
          ],
        ),
      ),
      body: provider.isLoading && !provider.profile.hasContent
          ? const Center(child: CircularProgressIndicator())
          : !provider.profile.initialized
              ? _buildUninitializedState(theme, provider)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPortraitTab(provider.profile, theme),
                    _buildTraitsTab(provider.profile, theme),
                    _buildInterestsTab(provider.profile, theme, provider),
                    _buildCognitionTab(provider.profile, theme),
                  ],
                ),
    );
  }

  Widget _buildUninitializedState(ThemeData theme, ProfileProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_alt, size: 72, color: theme.colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('画像还在慢慢攒', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('先去推荐页多看一阵，我会从你的点击、喜欢和对话中逐渐理解你。\n积累足够互动后，画像会自动生成。', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
            const SizedBox(height: 24),
            if (provider.profile.layers.isNotEmpty || provider.profile.interests.isNotEmpty)
              ElevatedButton(onPressed: () => provider.regenerateProfile(), child: const Text('立即生成画像')),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitTab(ProfileSummary profile, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.portrait.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20), const SizedBox(width: 8), const Text('人格素描', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 12),
                  Text(profile.portrait, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (profile.mbti.type.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.psychology, size: 20), const SizedBox(width: 8), const Text('MBTI 推断', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), Text('${(profile.mbti.confidence * 100).toInt()}% 置信度', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))]),
                  const SizedBox(height: 12),
                  Center(child: Text(profile.mbti.type, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, letterSpacing: 4))),
                  const SizedBox(height: 16),
                  ...profile.mbti.dimensions.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Text(e.key, style: theme.textTheme.bodySmall), const Spacer(), Text('${e.value.pole} (${(e.value.strength * 100).toInt()}%)', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: e.value.strength, backgroundColor: theme.dividerColor),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (profile.deepNeeds.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.favorite, size: 20), const SizedBox(width: 8), const Text('深层心理需求', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: profile.deepNeeds.map((n) => Chip(label: Text(n))).toList()),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTraitsTab(ProfileSummary profile, ThemeData theme) {
    if (profile.layers.isEmpty) return const Center(child: Text('暂无特质数据'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: profile.layers.length,
      itemBuilder: (context, index) {
        final layer = profile.layers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _layerColor(layer.level).withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(_layerLabel(layer.level), style: TextStyle(fontSize: 10, color: _layerColor(layer.level), fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(layer.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
                    Text('${(layer.weight * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
                if (layer.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(layer.summary, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                ],
                const SizedBox(height: 8),
                LinearProgressIndicator(value: layer.weight, backgroundColor: theme.dividerColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInterestsTab(ProfileSummary profile, ThemeData theme, ProfileProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.interests.isNotEmpty) ...[
          const Text('兴趣领域', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...profile.interests.map((interest) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: Text(interest.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))), Text('${(interest.weight * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))]),
                  if (interest.reason.isNotEmpty) ...[const SizedBox(height: 4), Text(interest.reason, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))],
                  if (interest.specifics.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 4, runSpacing: 4, children: interest.specifics.map((s) => Chip(label: Text(s), visualDensity: VisualDensity.compact)).toList()),
                  ],
                ],
              ),
            ),
          )),
        ],
        if (profile.avoidances.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('回避领域', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...profile.avoidances.map((avoid) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: theme.colorScheme.error.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [const Icon(Icons.block, size: 18, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text(avoid.name)), Text('${(avoid.weight * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))]),
            ),
          )),
        ],
        if (profile.speculativeInterests.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('猜测兴趣（试探中）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...profile.speculativeInterests.map((spec) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: theme.colorScheme.secondary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.help_outline, size: 18), const SizedBox(width: 8), Expanded(child: Text(spec.domain, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))), Text('${(spec.confidence * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))]),
                  if (spec.reason.isNotEmpty) ...[const SizedBox(height: 4), Text(spec.reason, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))],
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => provider.confirmSpeculation(spec.domain, true), child: const Text('确实感兴趣'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => provider.confirmSpeculation(spec.domain, false), child: const Text('不感兴趣'))),
                  ]),
                ],
              ),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildCognitionTab(ProfileSummary profile, ThemeData theme) {
    if (profile.cognitionUpdates.isEmpty) return const Center(child: Text('暂无认知更新记录'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: profile.cognitionUpdates.length,
      itemBuilder: (context, index) {
        final update = profile.cognitionUpdates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _impactColor(update.impact).withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(update.impact, style: TextStyle(fontSize: 10, color: _impactColor(update.impact), fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(update.summary, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                ]),
                if (update.reasoning.isNotEmpty) ...[const SizedBox(height: 8), Text(update.reasoning, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))],
                if (update.evidence.isNotEmpty) ...[const SizedBox(height: 8), Text('依据：${update.evidence}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _layerColor(String level) {
    switch (level) {
      case 'soul': return Colors.purple;
      case 'insight': return Colors.deepPurple;
      case 'awareness': return Colors.indigo;
      case 'preference': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _layerLabel(String level) {
    switch (level) {
      case 'soul': return '灵魂层';
      case 'insight': return '洞察层';
      case 'awareness': return '觉察层';
      case 'preference': return '偏好层';
      default: return '事件层';
    }
  }

  Color _impactColor(String impact) {
    switch (impact) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
