import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'services/password_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/lock_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先 await 加载本地配置，再 runApp，避免 build 里同步取 null（课程 m10 EX21）
  await SettingsService.init();
  await AppState.instance.init();

  final needLock =
      SettingsService.passwordLockEnabled && await PasswordService.hasPassword();

  runApp(MyApp(initialLocked: needLock));
}

class MyApp extends StatefulWidget {
  final bool initialLocked;

  const MyApp({super.key, required this.initialLocked});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late bool _locked;

  @override
  void initState() {
    super.initState();
    _locked = widget.initialLocked;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 从后台回到前台时，若密码锁开启则重新要求解锁
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 打开系统相册等场景回来不锁定
    if (PasswordService.suppressNextAutoLock) {
      PasswordService.suppressNextAutoLock = false;
      return;
    }
    if (_locked || !SettingsService.passwordLockEnabled) return;
    setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        return MaterialApp(
          title: '备忘录',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: AppState.instance.darkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const HomePage(),
          // 锁屏以覆盖层呈现，不销毁底层页面：
          // 避免选图返回、切换前后台时正在编辑的内容被重置
          builder: (context, child) {
            return Stack(
              children: [
                ?child,
                if (_locked)
                  LockPage(
                    onSuccess: () => setState(() => _locked = false),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
