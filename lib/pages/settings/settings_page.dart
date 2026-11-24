import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/database_helper.dart';
import '../../services/password_service.dart';
import '../../services/settings_service.dart';
import '../../state/app_state.dart';
import '../../state/nav_state.dart';

/// 设置页
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final db = DatabaseHelper.instance;

  int _noteCount = 0;
  bool _defaultCategoryEnabled = false;
  int? _defaultCategoryId;
  bool _passwordLockEnabled = false;
  List<Category> _categories = [];

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
    final count = await db.countNotes();
    final cats = await db.getAllCategories();
    if (!mounted) return;
    setState(() {
      _noteCount = count;
      _categories = cats;
      _defaultCategoryEnabled = SettingsService.defaultCategoryEnabled;
      _defaultCategoryId = SettingsService.defaultCategoryId;
      _passwordLockEnabled = SettingsService.passwordLockEnabled;
    });
  }

  String? get _defaultCategoryName {
    if (_defaultCategoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _defaultCategoryId) return c.name;
    }
    return null;
  }

  // ===================== 默认分类 =====================

  Future<void> _pickDefaultCategory() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final c = _categories[i];
              final selected = c.id == _defaultCategoryId;
              return ListTile(
                title: Text(c.name),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, c.id),
              );
            },
          ),
        );
      },
    );
    if (selected != null) {
      await SettingsService.setDefaultCategoryId(selected);
      setState(() => _defaultCategoryId = selected);
    }
  }

  // ===================== 密码锁 =====================

  /// 设置新密码（两个输入框校验一致）
  Future<String?> _askNewPassword() async {
    final pwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('设置密码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '密码不少于 6 位，需同时包含数字和字母或符号',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pwdCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '新密码'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '确认密码'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                TextButton(
                  onPressed: () {
                    final pwd = pwdCtrl.text;
                    if (pwd.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('密码不能为空')),
                      );
                      return;
                    }
                    if (pwd.length < 6) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('密码长度不能少于 6 位')),
                      );
                      return;
                    }
                    final hasDigit = RegExp(r'[0-9]').hasMatch(pwd);
                    final hasNonDigit = RegExp(r'[^0-9]').hasMatch(pwd);
                    if (!hasDigit || !hasNonDigit) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('密码需同时包含数字和字母或符号')),
                      );
                      return;
                    }
                    if (pwd != confirmCtrl.text) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('两次输入不一致')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, pwd);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  /// 验证当前密码，返回是否通过
  Future<bool> _verifyCurrentPassword() async {
    final ctrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('验证密码'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: '请输入当前密码'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('确定')),
          ],
        );
      },
    );
    if (input == null) return false;
    return PasswordService.verify(input);
  }

  Future<void> _togglePasswordLock(bool value) async {
    if (value) {
      // 开启：设置新密码
      final pwd = await _askNewPassword();
      if (pwd == null) return;
      await PasswordService.setPassword(pwd);
      await SettingsService.setPasswordLockEnabled(true);
      setState(() => _passwordLockEnabled = true);
    } else {
      // 关闭：验证当前密码
      final ok = await _verifyCurrentPassword();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('密码错误，无法关闭密码锁')),
          );
        }
        return;
      }
      await PasswordService.clearPassword();
      await SettingsService.setPasswordLockEnabled(false);
      setState(() => _passwordLockEnabled = false);
    }
  }

  Future<void> _changePassword() async {
    final ok = await _verifyCurrentPassword();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码错误')),
        );
      }
      return;
    }
    final pwd = await _askNewPassword();
    if (pwd == null) return;
    await PasswordService.setPassword(pwd);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码修改成功')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            children: [
              // 用户信息卡
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(Icons.person,
                          size: 30, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('备忘录用户',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('共 $_noteCount 条笔记',
                            style: TextStyle(color: theme.hintColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              _sectionHeader('通用设置'),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('深色模式'),
                value: AppState.instance.darkMode,
                onChanged: (v) => AppState.instance.setDarkMode(v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.category_outlined),
                title: const Text('默认分类'),
                subtitle: _defaultCategoryEnabled
                    ? Text('新建笔记默认归入：${_defaultCategoryName ?? '未选择'}')
                    : null,
                value: _defaultCategoryEnabled,
                onChanged: (v) async {
                  await SettingsService.setDefaultCategoryEnabled(v);
                  setState(() => _defaultCategoryEnabled = v);
                },
              ),
              if (_defaultCategoryEnabled)
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('选择默认分类'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickDefaultCategory,
                ),
              SwitchListTile(
                secondary: const Icon(Icons.schedule_outlined),
                title: const Text('显示修改时间'),
                value: AppState.instance.showModifyTime,
                onChanged: (v) => AppState.instance.setShowModifyTime(v),
              ),
              const Divider(),
              _sectionHeader('安全'),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('设置密码锁'),
                subtitle: const Text('开启后每次进入 App 需输入密码'),
                value: _passwordLockEnabled,
                onChanged: _togglePasswordLock,
              ),
              if (_passwordLockEnabled)
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: const Text('修改密码'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).hintColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
