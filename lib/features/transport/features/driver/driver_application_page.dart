import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(driverServiceProvider).submitApplication(
            name: _nameController.text,
            phone: _phoneController.text,
            address: _addressController.text,
            carPlate: _plateController.text,
            carModel: _modelController.text,
            maxPassengers: _maxPassengers,
          );
      ref.invalidate(currentDriverApplicationProvider);
      if (mounted) context.go('/transport/driver/pending');
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
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '姓名'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: '電話'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: '地址'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _plateController,
                  decoration: const InputDecoration(labelText: '車牌'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: '車型（可選）'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _maxPassengers,
                  decoration: const InputDecoration(labelText: '可載人數'),
                  items: List.generate(8, (index) => index + 1)
                      .map((count) => DropdownMenuItem(
                          value: count, child: Text('$count 人')))
                      .toList(),
                  onChanged: (value) => setState(() => _maxPassengers = value!),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? '送出中...' : '送出審核'),
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
