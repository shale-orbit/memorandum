import 'package:shared_preferences/shared_preferences.dart';

/// 设置项存储：基于 shared_preferences
///
/// 只存少量配置开关，读键永远 ?? 默认值兜底（课程 m10 规范）。
/// 必须在 main 中先 await [init] 再 runApp，避免 build 里同步取 null。
class SettingsService {
  SettingsService._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _ensure =>
      _prefs ?? (throw StateError('SettingsService.init() 未调用'));

  // ---------- 深色模式 ----------
  static bool get darkMode => _prefs?.getBool('dark_mode') ?? false;

  static Future<void> setDarkMode(bool value) =>
      _ensure.setBool('dark_mode', value);

  // ---------- 默认分类（新建笔记时自动归类） ----------
  static bool get defaultCategoryEnabled =>
      _prefs?.getBool('default_category_enabled') ?? false;

  static Future<void> setDefaultCategoryEnabled(bool value) =>
      _ensure.setBool('default_category_enabled', value);

  /// 默认分类 id（未设置则为 null）
  static int? get defaultCategoryId {
    final v = _prefs?.getInt('default_category_id');
    return v;
  }

  static Future<void> setDefaultCategoryId(int? id) async {
    if (id == null) {
      await _ensure.remove('default_category_id');
    } else {
      await _ensure.setInt('default_category_id', id);
    }
  }

  // ---------- 显示修改时间 ----------
  static bool get showModifyTime =>
      _prefs?.getBool('show_modify_time') ?? true;

  static Future<void> setShowModifyTime(bool value) =>
      _ensure.setBool('show_modify_time', value);

  // ---------- 密码锁开关 ----------
  static bool get passwordLockEnabled =>
      _prefs?.getBool('password_lock_enabled') ?? false;

  static Future<void> setPasswordLockEnabled(bool value) =>
      _ensure.setBool('password_lock_enabled', value);
}
