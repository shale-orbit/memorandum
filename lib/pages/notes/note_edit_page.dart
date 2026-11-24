import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/category.dart';
import '../../models/note.dart';
import '../../services/database_helper.dart';
import '../../services/password_service.dart';
import '../../utils/image_storage.dart';

/// 笔记新建 / 编辑页
class NoteEditPage extends StatefulWidget {
  final Note note;

  const NoteEditPage({super.key, required this.note});

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  final db = DatabaseHelper.instance;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  int? _categoryId;
  bool _isFavorite = false;
  String? _imagePath;
  String? _originalImagePath;
  bool _dirty = false;

  List<Category> _categories = [];

  bool get _isEditing => widget.note.id != null;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleCtrl = TextEditingController(text: n.title);
    _bodyCtrl = TextEditingController(text: n.body);
    _categoryId = n.categoryId;
    _isFavorite = n.isFavorite;
    _imagePath = n.imagePath;
    _originalImagePath = n.imagePath;
    // 新建笔记尚未落库，初始即为未保存状态
    _dirty = n.id == null;

    _titleCtrl.addListener(_markDirty);
    _bodyCtrl.addListener(_markDirty);

    _loadCategories();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _loadCategories() async {
    final list = await db.getAllCategories();
    if (!mounted) return;
    setState(() => _categories = list);
  }

  Category? get _currentCategory {
    if (_categoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    XFile? picked;
    // 打开系统相册会让 App 进入后台，临时抑制回来时自动上锁
    PasswordService.suppressNextAutoLock = true;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        // Android 13+ 走系统照片选择器时，部分 ROM（如 vivo）缺少媒体元数据
        // 读取权限会导致返回 null，关闭全量元数据读取规避
        requestFullMetadata: false,
      );
    } catch (e) {
      _showImageError('打开相册失败：$e');
      return;
    } finally {
      PasswordService.suppressNextAutoLock = false;
    }
    if (picked == null) {
      _showImageError('未获取到图片，请重新选择');
      return;
    }
    try {
      final path = await ImageStorage.save(picked);
      final previous = _imagePath;
      if (!mounted) return;
      setState(() {
        _imagePath = path;
        _dirty = true;
      });
      // 本次新插入的旧图（未落库）直接删除，避免残留
      if (previous != null && previous != _originalImagePath) {
        await ImageStorage.delete(previous);
      }
    } catch (e) {
      _showImageError('图片保存失败：$e');
    }
  }

  void _showImageError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _removeImage() async {
    final path = _imagePath;
    // 只清理本次新插入、尚未落库的图片；原图在保存成功或删除笔记时再清理
    if (path != null && path != _originalImagePath) {
      await ImageStorage.delete(path);
    }
    setState(() {
      _imagePath = null;
      _dirty = true;
    });
  }

  /// bottom sheet 里「新建分类」的占位返回值
  static const int _createCategoryMark = -1;

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in _categories)
                ListTile(
                  title: Text(c.name),
                  trailing: c.id == _categoryId ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, c.id),
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('新建分类'),
                onTap: () => Navigator.pop(ctx, _createCategoryMark),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected == _createCategoryMark) {
      await _createCategoryAndSelect();
      return;
    }
    setState(() {
      _categoryId = selected;
      _dirty = true;
    });
  }

  /// 在编辑页内直接新建分类，创建成功后自动选中
  Future<void> _createCategoryAndSelect() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分类'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分类名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('确定')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_categories.any((c) => c.name == trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该分类名已存在')),
      );
      return;
    }
    final id = await db.insertCategory(
      Category(name: trimmed, createdAt: DateTime.now()),
    );
    await _loadCategories();
    if (!mounted) return;
    setState(() {
      _categoryId = id;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    // 允许只有图片、没有文字
    if (title.isEmpty && body.isEmpty && _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题、正文和图片不能都为空')),
      );
      return;
    }
    final now = DateTime.now();
    final note = widget.note.copyWith(
      title: _titleCtrl.text,
      body: _bodyCtrl.text,
      categoryId: _categoryId,
      isFavorite: _isFavorite,
      imagePath: _imagePath,
      clearImagePath: _imagePath == null,
      updatedAt: now,
    );
    await db.saveNote(note);
    // 图片被移除或替换时，清理旧的图片文件
    if (_originalImagePath != null && _originalImagePath != _imagePath) {
      await ImageStorage.delete(_originalImagePath);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (widget.note.id == null) {
      Navigator.pop(context, false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定删除这条笔记吗？'),
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
    if (ok == true) {
      await db.deleteNote(widget.note.id!);
      // 删除笔记时清理其图片文件
      await ImageStorage.delete(widget.note.imagePath);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _copyContent() async {
    await Clipboard.setData(ClipboardData(text: _bodyCtrl.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('有未保存的修改'),
        content: const Text('是否放弃修改并退出？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('继续编辑')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _onWillPop();
        if (!allow || !context.mounted) return;
        // 放弃编辑时清理本次新插入、尚未落库的图片
        if (_imagePath != null && _imagePath != _originalImagePath) {
          await ImageStorage.delete(_imagePath);
        }
        if (context.mounted) Navigator.pop(context, false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑笔记' : '新建笔记'),
          actions: [
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.redAccent : null,
              ),
              onPressed: () {
                setState(() {
                  _isFavorite = !_isFavorite;
                  _dirty = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'copy') _copyContent();
                if (v == 'delete') _delete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'copy', child: Text('复制内容')),
                if (_isEditing)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 分类行
            InkWell(
              onTap: _pickCategory,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined,
                        size: 20, color: theme.hintColor),
                    const SizedBox(width: 10),
                    Text(
                      _currentCategory?.name ?? '选择分类',
                      style: TextStyle(
                        color: _currentCategory == null
                            ? theme.hintColor
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: theme.hintColor),
                  ],
                ),
              ),
            ),
            const Divider(),
            // 图片
            if (_imagePath != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // 标题
            TextField(
              controller: _titleCtrl,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: '标题',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const Divider(),
            // 正文
            TextField(
              controller: _bodyCtrl,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              decoration: const InputDecoration(
                hintText: '写点什么...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _pickImage,
                  tooltip: '插入图片',
                ),
                const Spacer(),
                Text(
                  _dirty ? '有未保存修改' : '已保存',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
