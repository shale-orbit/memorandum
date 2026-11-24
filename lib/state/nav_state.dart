import 'package:flutter/material.dart';

/// 底部导航索引的全局状态，供跨页面切换 Tab（如分类页"完成"跳回笔记页）
class NavState {
  NavState._();

  static final ValueNotifier<int> index = ValueNotifier<int>(0);

  /// 数据刷新信号：Tab 切换或点击刷新按钮时递增，各页监听后重新读库
  static final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);

  static void go(int i) {
    index.value = i;
  }

  /// 通知所有页面刷新本地数据
  static void refreshAll() {
    refreshTick.value++;
  }
}
