// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:smart_bp/shared/widgets/mindu_loading_overlay.dart';

/// 個人資料頁
///
/// 顯示並可編輯目前登入長輩的姓名 / 手機，寫回 Supabase `profiles` 資料表。
/// 整體沿用「明德 e 達人」大字、深綠主色、米黃底的長輩友善風格。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _backgroundCream = Color(0xFFFFF8E1);

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  Profile? _hydratedFor;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// 把 Provider 抓回來的 Profile 灌進 TextField 控制器。
  ///
  /// 只在第一次 hydrate 或 profile.id 變了的時候做，避免使用者打字打到一半被覆寫。
  void _hydrateIfNeeded(Profile? profile) {
    if (profile == null) return;
    if (_hydratedFor?.id == profile.id) return;
    _nameController.text = profile.name;
    _phoneController.text = profile.phone ?? '';
    _hydratedFor = profile;
  }

  Future<void> _onSave() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile(
            name: _nameController.text,
            phone: _phoneController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _primaryGreen,
          duration: Duration(seconds: 4),
          content: Text(
            '已存好您的資料，謝謝！',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      print('[Profile] update error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBF360C),
          duration: const Duration(seconds: 6),
          content: Text(
            '存檔失敗：$e',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: _backgroundCream,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          '個人資料',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        toolbarHeight: 72,
      ),
      body: SafeArea(
        child: MinduLoadingOverlay(
          isLoading: _isSaving,
          message: '正在存檔，請稍候...',
          child: asyncProfile.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            ),
            error: (e, _) => _ErrorBody(
              message: '讀取個人資料失敗：\n$e',
              onRetry: () => ref.read(profileProvider.notifier).refresh(),
            ),
            data: (profile) {
              if (profile == null) {
                return const _ErrorBody(
                  message: '尚未登入，請先回到登入頁。',
                );
              }
              _hydrateIfNeeded(profile);
              return _ProfileForm(
                formKey: _formKey,
                avatarChar: profile.firstChar,
                nameController: _nameController,
                phoneController: _phoneController,
                onSave: _onSave,
                onBack: _onBack,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.formKey,
    required this.avatarChar,
    required this.nameController,
    required this.phoneController,
    required this.onSave,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final String avatarChar;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _LargeAvatar(char: avatarChar)),
            const SizedBox(height: 28),
            const _FieldLabel(label: '您的姓名'),
            const SizedBox(height: 8),
            _BigTextField(
              controller: nameController,
              hint: '例如：王大明',
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請填寫姓名喔';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const _FieldLabel(label: '聯絡手機'),
            const SizedBox(height: 8),
            _BigTextField(
              controller: phoneController,
              hint: '例如：0912345678',
              keyboardType: TextInputType.phone,
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return null; // 手機可選
                if (!RegExp(r'^09\d{8}$').hasMatch(v)) {
                  return '手機格式好像怪怪的，請確認是 10 碼數字 0912345678';
                }
                return null;
              },
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 80,
              child: FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _ProfilePageState._primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '儲存修改',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ProfilePageState._primaryGreen,
                  side: const BorderSide(
                    color: _ProfilePageState._primaryGreen,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '取消，返回上一頁',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: _ProfilePageState._primaryGreen,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: _ProfilePageState._primaryGreen,
      ),
    );
  }
}

class _BigTextField extends StatelessWidget {
  const _BigTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: false,
      validator: validator,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 22, color: Colors.black38),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _ProfilePageState._primaryGreen,
            width: 2,
          ),
        ),
        errorStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFBF360C), size: 64),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFBF360C),
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 28),
                label: const Text(
                  '重新讀取',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _ProfilePageState._primaryGreen,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
