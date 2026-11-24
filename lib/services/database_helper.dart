import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/note.dart';

/// 数据库助手：笔记与分类的 sqflite 存储
///
/// 遵循课程 m10 规范：
/// - 所有 IO 均为 Future，await 不漏
/// - 搜索使用参数化 whereArgs，防 SQL 注入
/// - 带 version + onCreate + onUpgrade，迁移三件套预留
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  static const String _dbName = 'memorandum.db';
  static const int _dbVersion = 1;

  static const String tableNotes = 'notes';
  static const String tableCategories = 'categories';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 首次建库：建表 + 插入预置分类
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableNotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT,
        category_id INTEGER,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        image_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 预置分类：未分类(不可删)、学习、生活、工作
    final now = DateTime.now().toIso8601String();
    final presets = [
      Category.uncategorized,
      '学习',
      '生活',
      '工作',
    ];
    for (final name in presets) {
      await db.insert(tableCategories, {
        'name': name,
        'created_at': now,
      });
    }
  }

  /// 版本迁移：老用户旧库升级时走这里（当前 v1，预留）
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 示例：if (oldVersion < 2) { await db.execute('ALTER TABLE ... ADD COLUMN ...'); }
  }

  // ===================== 笔记 CRUD =====================

  Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert(tableNotes, note.toMap());
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    if (note.id == null) return 0;
    return db.update(
      tableNotes,
      note.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  /// 新增或更新：id 为空则插入，否则更新
  Future<int> saveNote(Note note) async {
    if (note.id == null) {
      return insertNote(note);
    }
    return updateNote(note);
  }

  /// 只更新笔记所属分类（长按「添加分类」用），同时刷新修改时间
  Future<int> updateNoteCategory(int noteId, int categoryId) async {
    final db = await database;
    return db.update(
      tableNotes,
      {
        'category_id': categoryId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete(tableNotes, where: 'id = ?', whereArgs: [id]);
  }

  Future<Note?> getNote(int id) async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  /// 全部笔记（按更新时间倒序）
  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  /// 按分类查询笔记（categoryId 为 null 查全部）
  Future<List<Note>> getNotesByCategory(int? categoryId) async {
    final db = await database;
    final rows = categoryId == null
        ? await db.query(tableNotes, orderBy: 'updated_at DESC')
        : await db.query(
            tableNotes,
            where: 'category_id = ?',
            whereArgs: [categoryId],
            orderBy: 'updated_at DESC',
          );
    return rows.map(Note.fromMap).toList();
  }

  /// 收藏的笔记
  Future<List<Note>> getFavoriteNotes() async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  /// 关键词搜索（标题或正文，参数化防注入）
  Future<List<Note>> searchNotes(String keyword) async {
    final db = await database;
    final kw = '%$keyword%';
    final rows = await db.query(
      tableNotes,
      where: 'title LIKE ? OR body LIKE ?',
      whereArgs: [kw, kw],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  /// 笔记总数（设置页统计用）
  Future<int> countNotes() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $tableNotes');
    return (result.first['c'] as int?) ?? 0;
  }

  /// 某分类下的笔记数量
  Future<int> countNotesInCategory(int? categoryId) async {
    final db = await database;
    if (categoryId == null) {
      return countNotes();
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableNotes WHERE category_id = ?',
      [categoryId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// 切换收藏状态，返回更新后的状态
  Future<bool> toggleFavorite(int noteId, bool current) async {
    final db = await database;
    await db.update(
      tableNotes,
      {'is_favorite': current ? 0 : 1},
      where: 'id = ?',
      whereArgs: [noteId],
    );
    return !current;
  }

  // ===================== 分类 CRUD =====================

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final rows = await db.query(tableCategories, orderBy: 'id ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<Category?> getCategory(int id) async {
    final db = await database;
    final rows = await db.query(
      tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<Category?> getCategoryByName(String name) async {
    final db = await database;
    final rows = await db.query(
      tableCategories,
      where: 'name = ?',
      whereArgs: [name],
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  /// 获取"未分类"分类
  Future<Category> getUncategorized() async {
    var cat = await getCategoryByName(Category.uncategorized);
    if (cat == null) {
      // 兜底：若被异常删除则重建
      final id = await insertCategory(
        Category(name: Category.uncategorized, createdAt: DateTime.now()),
      );
      cat = await getCategory(id);
    }
    return cat!;
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return db.insert(tableCategories, category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    if (category.id == null) return 0;
    return db.update(
      tableCategories,
      category.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// 删除分类：其下笔记移入"未分类"，"未分类"本身不可删除
  Future<bool> deleteCategory(int id) async {
    final db = await database;
    final cat = await getCategory(id);
    if (cat == null || cat.isUncategorized) return false;

    final uncategorized = await getUncategorized();
    await db.transaction((txn) async {
      // 把该分类下的笔记移到未分类
      await txn.update(
        tableNotes,
        {'category_id': uncategorized.id},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete(tableCategories, where: 'id = ?', whereArgs: [id]);
    });
    return true;
  }
}
