import 'package:flutter/material.dart';

import '../state/nav_state.dart';
import 'notes/notes_page.dart';
import 'categories/categories_page.dart';
import 'favorites/favorites_page.dart';
import 'settings/settings_page.dart';

/// 主框架：底部 4 Tab 导航（笔记 / 分类 / 收藏 / 设置）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Widget> _pages = const [
    NotesPage(),
    CategoriesPage(),
    FavoritesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NavState.index,
      builder: (context, currentIndex, _) {
        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              NavState.go(index);
              // IndexedStack 会保活各页，切换时主动通知刷新，避免显示旧数据
              NavState.refreshAll();
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.notes_outlined),
                selectedIcon: Icon(Icons.notes),
                label: '笔记',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: '分类',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: '收藏',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        );
      },
    );
  }
}
