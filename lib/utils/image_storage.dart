import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 笔记图片的本地存储工具
///
/// 图片统一写入 App 私有目录（与数据库同级），数据库只存路径；
/// 删除笔记或放弃编辑时调用 [delete] 清理文件，避免产生孤儿文件。
///
/// 注意：这里刻意不使用 path_provider，避开部分 ROM（如 vivo）上
/// getApplicationDocumentsDirectory 抛 ClassNotFoundException 的问题。
class ImageStorage {
  ImageStorage._();

  /// 图片目录：sqflite 数据库目录的上一级下的 note_images
  static Future<Directory> _dir() async {
    final dbPath = await getDatabasesPath();
    final base = Directory(dbPath).parent;
    final dir = Directory(p.join(base.path, 'note_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 把相册选中的图片写入私有目录，返回持久化后的路径
  ///
  /// 通过 readAsBytes 读取，兼容部分 ROM 返回 content:// 或缓存路径的情况
  static Future<String> save(XFile picked) async {
    final dir = await _dir();
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = File(p.join(dir.path, fileName));
    final bytes = await picked.readAsBytes();
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  /// 删除图片文件，不存在或清理失败时静默忽略
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      return;
    }
  }
}
