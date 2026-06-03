import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  var _saving = false;
  var _hydrated = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileServiceProvider).updateCurrentProfile(
            fullName: _nameController.text,
            phone: _phoneController.text,
            emergencyContactName: _emergencyNameController.text,
            emergencyContactPhone: _emergencyPhoneController.text,
            emergencyContactRelation: _emergencyRelationController.text,
          );
      if (!mounted) return;
      ref.invalidate(currentProfileProvider);
      context.go('/');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    if (!mounted) return;
    ref.invalidate(currentProfileProvider);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    if (!_hydrated && profile != null) {
      _hydrated = true;
      _nameController.text = profile.fullName ?? '';
      _phoneController.text = profile.phone ?? '';
      _emergencyNameController.text = profile.emergencyContactName ?? '';
      _emergencyPhoneController.text = profile.emergencyContactPhone ?? '';
      _emergencyRelationController.text =
          profile.emergencyContactRelation ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料設定'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _signOut,
            icon: const Icon(Icons.logout),
            tooltip: '登出',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '姓名'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '請輸入姓名' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '電話'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '請輸入電話' : null,
                ),
                const SizedBox(height: 28),
                Text('緊急聯絡人', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyNameController,
                  decoration: const InputDecoration(labelText: '聯絡人姓名'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '聯絡人電話'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emergencyRelationController,
                  decoration: const InputDecoration(labelText: '關係'),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '儲存中...' : '儲存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
