import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/database_helper.dart';
import '../../state/nav_state.dart';

/// 分类与标签页
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final db = DatabaseHelper.instance;

  List<Category> _categories = [];
  Map<int, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    NavState.refreshTick.addListener(_onRefreshTick);
  }

  @override
  void dispose() {
    NavState.refreshTick.removeListener(_onRefreshTick);
    super.dispose();
  }

  void _onRefreshTick() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cats = await db.getAllCategories();
    final counts = <int, int>{};
    for (final c in cats) {
      if (c.id != null) {
        counts[c.id!] = await db.countNotesInCategory(c.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _showNameDialog({Category? existing}) async {
    final ctrl = TextEditingController(text: existing?.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? '新建分类' : '重命名分类'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '分类名称'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('确定')),
          ],
        );
      },
    );
    if (name == null) return;
    if (!mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final dup = _categories
        .any((c) => c.name == trimmed && c.id != existing?.id);
    if (dup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该分类名已存在')),
      );
      return;
    }
    if (existing == null) {
      await db.insertCategory(
          Category(name: trimmed, createdAt: DateTime.now()));
    } else {
      await db.updateCategory(existing.copyWith(name: trimmed));
    }
    _load();
  }

  Future<void> _deleteCategory(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text(
            '删除分类「${c.name}」后，其下的 ${_counts[c.id] ?? 0} 条笔记将移入「未分类」，确定删除吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && c.id != null) {
      final success = await db.deleteCategory(c.id!);
      if (success) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类与标签'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建分类',
            onPressed: () => _showNameDialog(),
          ),
          TextButton(
            onPressed: () {
              NavState.go(0);
              // 分类可能已变动，通知笔记页刷新筛选栏
              NavState.refreshAll();
            },
            child: Text(
              '完成',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = _categories[index];
                final isUncategorized = c.isUncategorized;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(Icons.folder_outlined,
                        size: 18, color: theme.colorScheme.primary),
                  ),
                  title: Text(c.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_counts[c.id] ?? 0}',
                        style: TextStyle(color: theme.hintColor),
                      ),
                      if (!isUncategorized) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 20,
                          onPressed: () => _showNameDialog(existing: c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          iconSize: 20,
                          onPressed: () => _deleteCategory(c),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
