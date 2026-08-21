import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../models/chat.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatProvider>().sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('对话调教'),
            Text('告诉我你喜欢什么，我会调整推荐', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${provider.unreadCount}'),
              isLabelVisible: provider.unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: '消息',
            onPressed: () => _showNotifications(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: provider.isLoading && provider.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.messages.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.messages.length + (provider.isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == provider.messages.length && provider.isSending) {
                            return _buildTypingIndicator(theme);
                          }
                          final msg = provider.messages[index];
                          return _buildMessageBubble(msg, theme);
                        },
                      ),
          ),
          _buildInputArea(theme, provider),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('和我聊聊你的喜好', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('比如：我喜欢看科技数码视频\n或者：别给我推游戏内容了', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickChip('我喜欢科技数码'),
              _buildQuickChip('多看点电影解说'),
              _buildQuickChip('少推游戏内容'),
              _buildQuickChip('推荐一些深度内容'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: theme.colorScheme.primary, child: const Icon(Icons.smart_toy, size: 18, color: Colors.white)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Container(
                width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatTurn msg, ThemeData theme) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(radius: 16, backgroundColor: theme.colorScheme.primary, child: const Icon(Icons.smart_toy, size: 18, color: Colors.white)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? theme.colorScheme.primary : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: isUser ? null : Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? msg.message : (msg.reply.isNotEmpty ? msg.reply : msg.message),
                    style: TextStyle(color: isUser ? Colors.white : null, height: 1.4),
                  ),
                  if (msg.hasError) ...[
                    const SizedBox(height: 8),
                    Text(msg.error ?? '出错了', style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, ChatProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, border: Border(top: BorderSide(color: theme.dividerColor))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '告诉我你的喜好...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: provider.isSending ? null : _sendMessage,
              icon: provider.isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _NotificationSheet(),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('消息通知', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(onPressed: () => provider.markAllRead(), child: const Text('全部已读')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: provider.notifications.isEmpty
                  ? const Center(child: Text('暂无消息'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: provider.notifications.length,
                      itemBuilder: (context, index) {
                        final notif = provider.notifications[index];
                        return ListTile(
                          leading: Icon(_getNotificationIcon(notif.type), color: notif.read ? Colors.grey : theme.colorScheme.primary),
                          title: Text(notif.title, style: TextStyle(fontWeight: notif.read ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Text(notif.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Text(_formatTime(notif.createdAt), style: theme.textTheme.bodySmall),
                          onTap: () => provider.markNotificationRead(notif.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'interest_probe': return Icons.help_outline;
      case 'cognition_update': return Icons.psychology;
      case 'delight': return Icons.auto_awesome;
      default: return Icons.notifications;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
