import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/category.dart';
import '../../models/note.dart';
import '../../services/database_helper.dart';
import '../../services/settings_service.dart';
import '../../state/nav_state.dart';
import '../../utils/image_storage.dart';
import '../../widgets/note_card.dart';
import 'note_edit_page.dart';

/// 笔记首页
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final db = DatabaseHelper.instance;

  List<Note> _notes = [];
  List<Category> _categories = [];
  int? _selectedCategoryId; // null 表示全部
  String _keyword = '';
  bool _loading = true;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadNotes();
    NavState.refreshTick.addListener(_onRefreshTick);
  }

  @override
  void dispose() {
    NavState.refreshTick.removeListener(_onRefreshTick);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 切 Tab 或点刷新按钮时重新读库，保证数据最新
  void _onRefreshTick() {
    if (!mounted) return;
    _loadCategories();
    _loadNotes();
  }

  Future<void> _loadCategories() async {
    final list = await db.getAllCategories();
    if (!mounted) return;
    setState(() {
      _categories = list;
      // 选中的分类若已被删除，回退到「全部」
      if (_selectedCategoryId != null &&
          !list.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
    });
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    List<Note> list;
    if (_keyword.trim().isNotEmpty) {
      // 搜索：全局关键词搜索（参数化，防注入）
      list = await db.searchNotes(_keyword.trim());
    } else if (_selectedCategoryId == null) {
      list = await db.getAllNotes();
    } else {
      list = await db.getNotesByCategory(_selectedCategoryId);
    }
    if (!mounted) return;
    setState(() {
      _notes = list;
      _loading = false;
    });
  }

  /// 手动刷新：重新读取分类与笔记，并提示当前状态已同步
  Future<void> _refresh() async {
    await _loadCategories();
    await _loadNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已刷新'), duration: Duration(seconds: 1)),
    );
  }

  Category? _categoryOf(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _newNote() async {
    int? initCategoryId;
    if (SettingsService.defaultCategoryEnabled &&
        SettingsService.defaultCategoryId != null) {
      initCategoryId = SettingsService.defaultCategoryId;
    } else {
      final uncat = await db.getUncategorized();
      initCategoryId = uncat.id;
    }
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditPage(note: Note.empty(categoryId: initCategoryId)),
      ),
    );
    if (changed == true) {
      _loadCategories();
      _loadNotes();
    }
  }

  Future<void> _openNote(Note note) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditPage(note: note)),
    );
    if (changed == true) {
      _loadCategories();
      _loadNotes();
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    if (note.id == null) return;
    await db.toggleFavorite(note.id!, note.isFavorite);
    _loadNotes();
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
    _loadCategories();
    _loadNotes();
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
                leading: Icon(note.isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border),
                title: Text(note.isFavorite ? '取消收藏' : '收藏'),
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
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) {
              setState(() {
                _keyword = v;
                // 关键词搜索为全局搜索，清掉分类筛选高亮
                if (v.trim().isNotEmpty) _selectedCategoryId = null;
              });
              // 300ms 防抖，避免每输入一个字符都查库
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) _loadNotes();
              });
            },
            decoration: const InputDecoration(
              hintText: '搜索笔记',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('暂无新提醒'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterBar(theme),
        ),
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: _newNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip('全部', null, theme),
          ..._categories.map((c) => _filterChip(c.name, c.id, theme)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int? id, ThemeData theme) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryId = id;
            _keyword = '';
          });
          _searchCtrl.clear();
          _loadNotes();
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 2.5,
                width: 18,
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes_outlined, size: 64, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              _keyword.isNotEmpty ? '没有找到相关笔记' : '还没有笔记，点击右下角 + 创建',
              style: TextStyle(color: theme.hintColor),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
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
    );
  }
}
