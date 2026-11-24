import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/category.dart';
import '../../models/note.dart';
import '../../services/database_helper.dart';
import '../../state/nav_state.dart';
import '../../utils/image_storage.dart';
import '../../widgets/note_card.dart';
import '../notes/note_edit_page.dart';

/// 收藏列表页
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final db = DatabaseHelper.instance;

  List<Note> _notes = [];
  List<Category> _categories = [];
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
    final favs = await db.getFavoriteNotes();
    final cats = await db.getAllCategories();
    if (!mounted) return;
    setState(() {
      _notes = favs;
      _categories = cats;
      _loading = false;
    });
  }

  Category? _categoryOf(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _openNote(Note note) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditPage(note: note)),
    );
    if (changed == true) _load();
  }

  Future<void> _toggleFavorite(Note note) async {
    if (note.id == null) return;
    await db.toggleFavorite(note.id!, note.isFavorite);
    _load();
  }

  /// 长按菜单「添加分类」：选择目标分类后更新笔记归属
  Future<void> _pickCategoryFor(Note note) async {
    if (note.id == null) return;
    final categories = await db.getAllCategories();
    if (!mounted) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final c = categories[i];
            return ListTile(
              title: Text(c.name),
              trailing:
                  c.id == note.categoryId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, c.id),
            );
          },
        ),
      ),
    );
    if (selected == null) return;
    await db.updateNoteCategory(note.id!, selected);
    _load();
  }

  void _showActions(Note note) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('取消收藏'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _toggleFavorite(note);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('添加分类'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickCategoryFor(note);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制内容'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(ClipboardData(text: note.body));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  _confirmDelete(note);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Note note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定删除「${note.title.isEmpty ? '无标题' : note.title}」吗？'),
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
    if (ok == true && note.id != null) {
      await db.deleteNote(note.id!);
      // 同时清理该笔记的图片文件
      await ImageStorage.delete(note.imagePath);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('收藏列表')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 64, color: theme.hintColor),
                      const SizedBox(height: 12),
                      Text('还没有收藏的笔记',
                          style: TextStyle(color: theme.hintColor)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return NoteCard(
                      note: note,
                      category: _categoryOf(note.categoryId),
                      onTap: () => _openNote(note),
                      onLongPress: () => _showActions(note),
                      onFavoriteTap: () => _toggleFavorite(note),
                    );
                  },
                ),
    );
  }
}
