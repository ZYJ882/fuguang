import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'recommend_view.dart';
import 'chat_view.dart';
import 'profile_view.dart';
import 'saved_view.dart';
import 'settings_view.dart';
import '../providers/app_providers.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    RecommendView(),
    SavedView(),
    ChatView(),
    ProfileView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: '推荐'),
          const NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: '内容库'),
          NavigationDestination(
            icon: Badge(label: chatProvider.unreadCount > 0 ? Text('${chatProvider.unreadCount}') : null, isLabelVisible: chatProvider.unreadCount > 0, child: const Icon(Icons.chat_bubble_outline)),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: '对话',
          ),
          const NavigationDestination(icon: Icon(Icons.psychology_alt_outlined), selectedIcon: Icon(Icons.psychology_alt), label: '画像'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
