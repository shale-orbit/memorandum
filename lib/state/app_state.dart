import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

/// 全局应用状态：深色模式等需要跨页面联动的配置
class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  bool _darkMode = false;
  bool get darkMode => _darkMode;

  bool _showModifyTime = true;
  bool get showModifyTime => _showModifyTime;

  /// 启动时从本地读取（需先 SettingsService.init()）
  Future<void> init() async {
    _darkMode = SettingsService.darkMode;
    _showModifyTime = SettingsService.showModifyTime;
  }

  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    await SettingsService.setDarkMode(value);
    notifyListeners();
  }

  Future<void> setShowModifyTime(bool value) async {
    if (_showModifyTime == value) return;
    _showModifyTime = value;
    await SettingsService.setShowModifyTime(value);
    notifyListeners();
  }
}
