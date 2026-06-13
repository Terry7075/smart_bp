import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';

class DriverApplicationPage extends ConsumerStatefulWidget {
  const DriverApplicationPage({super.key});

  @override
  ConsumerState<DriverApplicationPage> createState() =>
      _DriverApplicationPageState();
}

class _DriverApplicationPageState extends ConsumerState<DriverApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  var _maxPassengers = 4;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _plateController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(driverServiceProvider)
          .submitApplication(
            name: _nameController.text,
            phone: _phoneController.text,
            address: _addressController.text,
            carPlate: _plateController.text,
            carModel: _modelController.text,
            maxPassengers: _maxPassengers,
          );

      ref.invalidate(currentDriverApplicationProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('司機申請已送出，等待管理員審核')));
      context.go('/transport/driver/pending');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final isDuplicate =
          error.code == '23505' ||
          error.message.toLowerCase().contains('duplicate');
      final message = isDuplicate
          ? '你已經送出過司機申請，請等待管理員審核'
          : '司機申請送出失敗：${error.message}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('司機申請送出失敗：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('申請成為司機')),
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
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: '電話'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: '地址'),
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plateController,
                  decoration: const InputDecoration(labelText: '車牌'),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: '車型（選填）'),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _maxPassengers,
                  decoration: const InputDecoration(labelText: '可載人數'),
                  items: List.generate(8, (index) => index + 1)
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count 人'),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _maxPassengers = value!),
                  validator: (value) =>
                      value == null || value <= 0 ? '請選擇可載人數' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? '送出中...' : '送出申請'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '必填' : null;
}
