import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../llm/llm_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _testingConnection = false;
  String? _connectionResult;
  String _selectedProvider = 'openai';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialSettings());
  }

  Future<void> _loadInitialSettings() async {
    final provider = context.read<SettingsProvider>();
    await provider.loadSettings();
    if (!mounted) return;
    final config = provider.llmConfig;
    setState(() {
      _selectedProvider = LLMProviderPreset.fromId(config.provider).id;
      _apiKeyController.text = config.apiKey;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.model;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSectionHeader('LLM 配置', theme),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '支持 OpenAI 兼容接口与 Claude 原生 Messages API；API Key 仅保存于设备安全存储。',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '当前服务：${LLMProviderPreset.fromId(_selectedProvider).name} · ${LLMProviderPreset.fromId(_selectedProvider).description}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                        labelText: 'API Key',
                        prefixIcon: Icon(Icons.key),
                        hintText: 'sk-...'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                        labelText: 'Base URL',
                        prefixIcon: Icon(Icons.link),
                        hintText: 'https://api.openai.com/v1'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: '模型名称',
                      prefixIcon: const Icon(Icons.psychology),
                      hintText: 'gpt-4o-mini / deepseek-chat',
                      suffixIcon: IconButton(
                        tooltip: '获取模型列表',
                        onPressed: _showModelPicker,
                        icon: const Icon(Icons.format_list_bulleted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _testingConnection ? null : _testConnection,
                          icon: _testingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync),
                          label: const Text('测试连接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveLLMConfig,
                          icon: const Icon(Icons.save),
                          label: const Text('保存配置'),
                        ),
                      ),
                    ],
                  ),
                  if (_connectionResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: _connectionResult!.contains('成功')
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(
                              _connectionResult!.contains('成功')
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _connectionResult!.contains('成功')
                                  ? Colors.green
                                  : Colors.red,
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_connectionResult!,
                                  style: theme.textTheme.bodySmall)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildPresetButtons(),
                ],
              ),
            ),
          ),
          _buildSectionHeader('内容来源', theme),
          ...['bilibili', 'xiaohongshu', 'douyin', 'zhihu', 'web']
              .map((platform) {
            final labels = {
              'bilibili': 'B站',
              'xiaohongshu': '小红书',
              'douyin': '抖音',
              'zhihu': '知乎',
              'web': '通用网页'
            };
            final requiresAuth = {
              'bilibili': false,
              'xiaohongshu': true,
              'douyin': true,
              'zhihu': false,
              'web': false
            };
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: _SourceIcon(platform: platform),
                title: Text(labels[platform] ?? platform),
                subtitle: requiresAuth[platform] == true
                    ? const Text('需要登录 Cookie')
                    : const Text('公开内容，无需登录'),
                trailing: Switch(
                  value: provider.sourceEnabled[platform] ?? true,
                  onChanged: (value) =>
                      provider.setSourceEnabled(platform, value),
                ),
                onTap: requiresAuth[platform] == true
                    ? () =>
                        _showCookieInput(platform, labels[platform] ?? platform)
                    : null,
              ),
            );
          }),
          _buildSectionHeader('通用设置', theme),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('显示模式'),
                  subtitle: Text(_themeModeDescription(provider.themeMode)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _themeModeTitle(provider.themeMode),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _showThemeModePicker(provider.themeMode),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('自动同步到平台'),
                  subtitle: const Text('收藏/稍后再看时尝试同步到对应平台'),
                  value: provider.autoSync,
                  onChanged: (value) => provider.setAutoSync(value),
                  secondary: const Icon(Icons.sync),
                ),
              ],
            ),
          ),
          _buildSectionHeader('关于', theme),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('浮光'),
                  subtitle: Text('v0.3.212 · 纯本地运行 · 无需服务器'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('隐私说明'),
                  subtitle: const Text('所有数据存储在本机 SQLite，LLM 调用使用你自己的 API Key'),
                  onTap: () => _showPrivacyDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('开源项目'),
                  subtitle: const Text('GitHub · ZYJ882/fuguang'),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: _openProjectRepository,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPresetButtons() {
    final presets = [
      ...LLMProviderPreset.presets,
      LLMProviderPreset.custom,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((preset) {
        final selected = _selectedProvider == preset.id;
        return ChoiceChip(
          label: Text(preset.name),
          selected: selected,
          onSelected: (_) {
            _switchProvider(preset.id);
          },
        );
      }).toList(),
    );
  }

  Future<void> _switchProvider(String providerId) async {
    await _saveLLMConfig(silent: true);
    final config =
        await context.read<SettingsProvider>().selectLLMProvider(providerId);
    if (!mounted) return;
    setState(() {
      _selectedProvider = config.provider;
      _apiKeyController.text = config.apiKey;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.model;
      _connectionResult = null;
    });
  }

  Future<void> _showModelPicker() async {
    await _saveLLMConfig(silent: true);
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    ModelListResult result = await settings.fetchLLMModels();
    if (!mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '无法加载模型列表')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        var models = result.models;
        var refreshing = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final visibleModels = models
                .where((model) =>
                    model.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('可用模型列表')),
                  IconButton(
                    tooltip: '刷新列表',
                    onPressed: refreshing
                        ? null
                        : () async {
                            setDialogState(() => refreshing = true);
                            final refreshed = await settings.fetchLLMModels();
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              refreshing = false;
                              if (refreshed.isSuccess)
                                models = refreshed.models;
                            });
                            if (!refreshed.isSuccess && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(refreshed.error ?? '无法刷新模型列表'),
                                ),
                              );
                            }
                          },
                    icon: refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜索模型',
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visibleModels.isEmpty
                          ? const Center(child: Text('没有匹配的模型'))
                          : ListView.separated(
                              itemCount: visibleModels.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final model = visibleModels[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(model),
                                  trailing: model == _modelController.text
                                      ? const Icon(Icons.check,
                                          color: Colors.green)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _modelController.text = model;
                                      _connectionResult = null;
                                    });
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openProjectRepository() async {
    final launched = await launchUrl(
      Uri.parse('https://github.com/ZYJ882/fuguang'),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开 GitHub 项目链接')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });
    await _saveLLMConfig(silent: true);
    final success = await context.read<SettingsProvider>().testLLMConnection();
    setState(() {
      _testingConnection = false;
      _connectionResult =
          success ? '连接成功！LLM 服务可用。' : '连接失败，请检查 API Key 和 Base URL。';
    });
  }

  Future<void> _saveLLMConfig({bool silent = false}) async {
    final config = LLMConfig(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );
    await context.read<SettingsProvider>().updateLLMConfig(config);
    if (!silent && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('配置已保存')));
    }
  }

  String _themeModeTitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.light:
        return '浅色模式';
    }
  }

  String _themeModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '使用设备当前的显示外观';
      case ThemeMode.dark:
        return '始终使用深色界面';
      case ThemeMode.light:
        return '始终使用浅色界面';
    }
  }

  Future<void> _showThemeModePicker(ThemeMode currentMode) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择显示模式'),
        contentPadding: const EdgeInsets.only(top: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: currentMode,
              title: const Text('跟随系统'),
              subtitle: const Text('自动使用设备当前的深色或浅色外观'),
              onChanged: (mode) => Navigator.pop(dialogContext, mode),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: currentMode,
              title: const Text('深色模式'),
              subtitle: const Text('始终使用深色界面'),
              onChanged: (mode) => Navigator.pop(dialogContext, mode),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: currentMode,
              title: const Text('浅色模式'),
              subtitle: const Text('始终使用浅色界面'),
              onChanged: (mode) => Navigator.pop(dialogContext, mode),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await context.read<SettingsProvider>().setThemeMode(selected);
    }
  }

  void _showCookieInput(String platform, String label) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('配置 $label Cookie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('在浏览器登录对应平台后，复制 Cookie 粘贴到下方：',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: '粘贴 Cookie...', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              context
                  .read<SettingsProvider>()
                  .setSourceCookies(platform, controller.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Cookie 已保存')));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私说明'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. 所有行为数据、画像、对话历史均存储在本机 SQLite 数据库中，不会上传到任何服务器。'),
              SizedBox(height: 8),
              Text('2. API Key 使用设备安全存储保护；启用 LLM 后，请求会直接发送到你选择的服务商。'),
              SizedBox(height: 8),
              Text('3. 内容来源数据直接从各平台公开 API 获取，不经过任何中间服务器。'),
              SizedBox(height: 8),
              Text('4. 你可以随时清除本地数据，卸载应用即删除所有数据。'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('我知道了'))
        ],
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final String platform;
  const _SourceIcon({required this.platform});

  @override
  Widget build(BuildContext context) {
    final icons = {
      'bilibili': Icons.play_circle_fill,
      'xiaohongshu': Icons.book,
      'douyin': Icons.music_note,
      'zhihu': Icons.question_answer,
      'web': Icons.language
    };
    final colors = {
      'bilibili': const Color(0xFFFB7299),
      'xiaohongshu': const Color(0xFFFF2442),
      'douyin': Colors.black,
      'zhihu': const Color(0xFF0066FF),
      'web': Colors.grey
    };
    return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: (colors[platform] ?? Colors.grey).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icons[platform] ?? Icons.language,
            color: colors[platform] ?? Colors.grey, size: 20));
  }
}
