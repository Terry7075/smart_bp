import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/shared/widgets/mindu_loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 登入／註冊頁（長輩友善大字體、高對比）。
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _LoginScaffold();
  }
}

class _LoginScaffold extends ConsumerStatefulWidget {
  const _LoginScaffold();

  @override
  ConsumerState<_LoginScaffold> createState() => _LoginScaffoldState();
}

class _LoginScaffoldState extends ConsumerState<_LoginScaffold> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    if (_isLoading) return;
    setState(() => _isLoginMode = !_isLoginMode);
  }

  Future<void> _onSubmit() async {
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider.notifier);
      if (_isLoginMode) {
        await auth.signIn(_emailController.text, _passwordController.text);
      } else {
        await auth.signUp(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
          _phoneController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('註冊成功，歡迎加入明德 e 達人！')),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_isLoginMode ? '登入' : '註冊'}失敗：${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_isLoginMode ? '登入' : '註冊'}失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google 登入失敗：${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google 登入失敗：$e')),
        );
      }
    } finally {
      // OAuth 會切換到瀏覽器完成授權，回到 App 前遮罩就先收起來，
      // 真正的登入成功由 onAuthStateChange + GoRouter redirect 接手。
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitLabel = _isLoginMode ? '登入' : '註冊';
    final toggleLabel = _isLoginMode ? '還沒有帳號？點此註冊' : '已有帳號？返回登入';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: MinduLoadingOverlay(
          isLoading: _isLoading,
          message: _isLoginMode ? '登入中，請稍候…' : '註冊中，請稍候…',
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '明德 e 達人',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? '請登入以繼續' : '建立新帳號',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 28),
                _GoogleSignInButton(
                  onPressed: _isLoading ? null : _onGoogleSignIn,
                ),
                const SizedBox(height: 24),
                const _OrDivider(),
                const SizedBox(height: 24),
                _BigTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _BigTextField(
                  controller: _passwordController,
                  label: '密碼',
                  obscureText: true,
                ),
                if (!_isLoginMode) ...[
                  const SizedBox(height: 20),
                  _BigTextField(
                    controller: _nameController,
                    label: '真實姓名',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 20),
                  _BigTextField(
                    controller: _phoneController,
                    label: '手機號碼',
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      textStyle: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(submitLabel),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _toggleMode,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: theme.colorScheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(toggleLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF202124),
          side: const BorderSide(color: Color(0xFFDADCE0), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: const _GoogleGLogo(size: 32),
        label: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text('使用 Google 快速登入'),
        ),
      ),
    );
  }
}

/// 以文字樣式模擬 Google 「G」商標，避免引入額外素材。
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        style: TextStyle(
          fontSize: size * 0.72,
          fontWeight: FontWeight.w900,
          height: 1,
          color: const Color(0xFF4285F4),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '或',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(child: Divider(color: color, thickness: 1)),
      ],
    );
  }
}

class _BigTextField extends StatelessWidget {
  const _BigTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: false,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
