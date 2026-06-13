// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_bp/features/medication/drug_dictionary_admin_provider.dart';

const Color _kVolunteerBlue = Color(0xFF1565C0);

/// 志工端：新增藥典。讓志工輸入藥品照片、中文名、英文名、學名、藥廠，
/// 逐步讓社區藥典齊全（長輩打卡頁即可看圖認藥）。
class VolunteerDrugDictionaryAddPage extends ConsumerStatefulWidget {
  const VolunteerDrugDictionaryAddPage({super.key});

  @override
  ConsumerState<VolunteerDrugDictionaryAddPage> createState() =>
      _VolunteerDrugDictionaryAddPageState();
}

class _VolunteerDrugDictionaryAddPageState
    extends ConsumerState<VolunteerDrugDictionaryAddPage> {
  final _nameZhController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _genericController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _picker = ImagePicker();

  String? _photoPath;
  bool _submitting = false;

  @override
  void dispose() {
    _nameZhController.dispose();
    _nameEnController.dispose();
    _genericController.dispose();
    _manufacturerController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (e) {
      print('[DrugDictionaryAdd] pick photo error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('挑選照片失敗：$e')),
        );
      }
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, size: 28),
              title: const Text('拍照', style: TextStyle(fontSize: 20)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 28),
              title: const Text('從相簿選擇', style: TextStyle(fontSize: 20)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_nameZhController.text.trim().isEmpty &&
        _nameEnController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFBF360C),
          content: Text('請至少填寫中文名或英文名其中一個。',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(drugDictionaryAdminProvider).addEntry(
            nameZh: _nameZhController.text,
            nameEn: _nameEnController.text,
            genericName: _genericController.text,
            manufacturer: _manufacturerController.text,
            localPhotoPath: _photoPath,
          );
      if (!mounted) return;
      // 清空表單，方便連續新增多筆。
      setState(() {
        _nameZhController.clear();
        _nameEnController.clear();
        _genericController.clear();
        _manufacturerController.clear();
        _photoPath = null;
        _submitting = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          content: Text('✅ 已加入藥典，感謝您讓藥典更齊全！',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      print('[DrugDictionaryAdd] submit error: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBF360C),
          duration: const Duration(seconds: 5),
          content: Text('新增失敗：${drugDictionaryFriendlyError(e)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kVolunteerBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _kVolunteerBlue, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '新增後，長輩在「吃藥打卡」時若拍到同款藥，就能看到這張照片認藥。'
                      '請至少填中文名或英文名，照片建議拍清楚藥袋或藥丸。',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _FieldLabel(icon: '📷', label: '藥品照片（建議上傳）'),
            const SizedBox(height: 8),
            _PhotoPicker(
              photoPath: _photoPath,
              onTap: _showPhotoSourceSheet,
              onClear: () => setState(() => _photoPath = null),
            ),
            const SizedBox(height: 20),
            const _FieldLabel(icon: '🇹🇼', label: '中文藥名'),
            const SizedBox(height: 8),
            _TextField(
              controller: _nameZhController,
              hint: '例如：脈優錠',
            ),
            const SizedBox(height: 20),
            const _FieldLabel(icon: '🔤', label: '英文藥名／商品名'),
            const SizedBox(height: 8),
            _TextField(
              controller: _nameEnController,
              hint: '例如：Norvasc',
            ),
            const SizedBox(height: 20),
            const _FieldLabel(icon: '🧪', label: '學名／成分（可留空）'),
            const SizedBox(height: 8),
            _TextField(
              controller: _genericController,
              hint: '例如：Amlodipine',
            ),
            const SizedBox(height: 20),
            const _FieldLabel(icon: '🏭', label: '藥廠（可留空）'),
            const SizedBox(height: 8),
            _TextField(
              controller: _manufacturerController,
              hint: '例如：輝瑞 Pfizer',
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('✅ 加入藥典',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        if (_submitting)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black38,
              child: Center(
                child: CircularProgressIndicator(
                    color: _kVolunteerBlue, strokeWidth: 6),
              ),
            ),
          ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 17, color: Colors.black38),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kVolunteerBlue, width: 2),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoPath,
    required this.onTap,
    required this.onClear,
  });

  final String? photoPath;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (photoPath == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black26, width: 1.4),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 44, color: _kVolunteerBlue),
              SizedBox(height: 8),
              Text('點此拍照或上傳藥品照片',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kVolunteerBlue)),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(photoPath!),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Material(
            color: _kVolunteerBlue,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('更換',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
