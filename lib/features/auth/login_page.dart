// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:smart_bp/shared/widgets/mindu_loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 將 Supabase 常見英文錯誤碼 / 訊息翻成長輩友善的中文說明。
String _friendlyAuthMessage(AuthException e) {
  final raw = e.message.toLowerCase();
  if (raw.contains('invalid login credentials') ||
      raw.contains('invalid_credentials')) {
    return '帳號或密碼不正確。若尚未註冊，請先點下方「還沒有帳號？點此註冊」。';
  }
  if (raw.contains('email not confirmed')) {
    return '此 Email 尚未完成驗證，請先到信箱點選 Supabase 寄出的驗證信。';
  }
  if (raw.contains('user already registered') ||
      raw.contains('already been registered')) {
    return '此 Email 已被註冊過，請改用「登入」。';
  }
  if (raw.contains('rate limit') || raw.contains('too many')) {
    return '請求過於頻繁，請稍後 5–10 分鐘再試。';
  }
  if (raw.contains('password should be at least')) {
    return '密碼長度不足，請改用至少 6 碼的密碼。';
  }
  return e.message;
}

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
  final _inviteCodeController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;

  /// 註冊模式下，使用者是否勾選「我是社區志工」。
  /// 勾選後才會顯示邀請碼輸入欄；切回登入模式時會被重設。
  bool _isVolunteer = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    if (_isLoading) return;
    setState(() {
      _isLoginMode = !_isLoginMode;
      // 切回登入模式：把志工相關欄位收乾淨，避免下次切回註冊時殘留。
      if (_isLoginMode) {
        _isVolunteer = false;
        _inviteCodeController.clear();
      }
    });
  }

  Future<void> _onSubmit() async {
    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider.notifier);
      if (_isLoginMode) {
        await auth.signIn(_emailController.text, _passwordController.text);
      } else {
        final role = _isVolunteer ? UserRole.volunteer : UserRole.elder;
        await auth.signUp(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
          _phoneController.text,
          role: role,
          inviteCode: _isVolunteer ? _inviteCodeController.text : null,
        );

        // 強制再 refresh 一次 profile：避免 onAuthStateChange 觸發的
        // 第一次抓資料比 signUp 內的 upsert（role=volunteer）還早跑完，
        // 導致 RoleDecisionPage 拿到舊 role 把志工導去長輩首頁。
        try {
          await ref.read(profileProvider.notifier).refresh();
        } catch (e) {
          print('[Auth] post-signUp profile refresh error: $e');
        }

        if (mounted) {
          final welcome = _isVolunteer
              ? '✅ 志工身分註冊成功，謝謝您加入明德 e 達人服務團隊！'
              : '✅ 註冊成功，歡迎加入明德 e 達人！';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 5),
              content: Text(
                welcome,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          );
        }
      }
    } on InvalidInviteCodeException catch (e) {
      print('[Auth] InvalidInviteCode: ${e.message}');
      if (mounted) {
        _showAuthError('註冊失敗', '❌ ${e.message}');
      }
    } on AuthException catch (e) {
      print('[Auth] AuthException code=${e.code} statusCode=${e.statusCode} message=${e.message}');
      if (mounted) {
        _showAuthError('${_isLoginMode ? '登入' : '註冊'}失敗', _friendlyAuthMessage(e));
      }
    } catch (e) {
      print('[Auth] Unknown error: $e');
      if (mounted) {
        _showAuthError('${_isLoginMode ? '登入' : '註冊'}失敗', '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAuthError(String title, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFFBF360C),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: '關閉',
          textColor: Colors.white,
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } on AuthException catch (e) {
      print('[Auth] Google AuthException code=${e.code} statusCode=${e.statusCode} message=${e.message}');
      if (mounted) {
        _showAuthError('Google 登入失敗', _friendlyAuthMessage(e));
      }
    } catch (e) {
      print('[Auth] Google Unknown error: $e');
      if (mounted) {
        _showAuthError('Google 登入失敗', '$e');
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
                  const SizedBox(height: 20),
                  _VolunteerToggle(
                    value: _isVolunteer,
                    onChanged: _isLoading
                        ? null
                        : (v) {
                            setState(() {
                              _isVolunteer = v;
                              if (!v) _inviteCodeController.clear();
                            });
                          },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _isVolunteer
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _BigTextField(
                              controller: _inviteCodeController,
                              label: '🔑 請輸入志工專屬邀請碼',
                              keyboardType: TextInputType.text,
                            ),
                          )
                        : const SizedBox.shrink(),
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

/// 註冊模式下的「我是社區志工」開關。
///
/// 使用 [SwitchListTile] 而非 [Checkbox]：開關的肢體動作對長輩更直覺，
/// 也避免註冊頁所有欄位被一個小小的方框打斷視覺節奏。
class _VolunteerToggle extends StatelessWidget {
  const _VolunteerToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? primary : const Color(0xFFDADCE0),
          width: value ? 2 : 1.5,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: primary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '🧑‍🤝‍🧑 我是社區志工',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '需要村辦公室提供的專屬邀請碼',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
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
