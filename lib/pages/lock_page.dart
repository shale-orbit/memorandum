import 'package:flutter/material.dart';

import '../services/password_service.dart';

/// 密码锁锁屏页：开启密码锁后每次启动 App 先验证
class LockPage extends StatefulWidget {
  final VoidCallback onSuccess;

  const LockPage({super.key, required this.onSuccess});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final _ctrl = TextEditingController();
  bool _error = false;
  bool _loading = false;

  Future<void> _unlock() async {
    if (_ctrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    final ok = await PasswordService.verify(_ctrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '备忘录已锁定',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请输入密码解锁',
                  style: TextStyle(color: theme.hintColor),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  obscureText: true,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '请输入密码',
                    errorText: _error ? '密码错误，请重试' : null,
                  ),
                  onChanged: (_) {
                    if (_error) setState(() => _error = false);
                  },
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _unlock,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('解锁'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
