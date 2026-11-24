import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 密码锁存储：基于 flutter_secure_storage
///
/// 课程 m10 红线：敏感数据不得明文落盘，密码进 Android Keystore 加密存储，
/// 严禁写进 shared_preferences。
class PasswordService {
  PasswordService._();

  static const _keyPassword = 'lock_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// 临时抑制下一次回到前台时自动上锁
  /// 用于打开系统相册等会短暂让 App 进入后台的场景
  static bool suppressNextAutoLock = false;

  /// 是否已设置密码
  static Future<bool> hasPassword() async {
    return _storage.containsKey(key: _keyPassword);
  }

  /// 设置/修改密码
  static Future<void> setPassword(String password) async {
    await _storage.write(key: _keyPassword, value: password);
  }

  /// 校验密码是否正确
  static Future<bool> verify(String input) async {
    final stored = await _storage.read(key: _keyPassword);
    if (stored == null) return false;
    return stored == input;
  }

  /// 清除密码（关闭密码锁时调用）
  static Future<void> clearPassword() async {
    await _storage.delete(key: _keyPassword);
  }
}
