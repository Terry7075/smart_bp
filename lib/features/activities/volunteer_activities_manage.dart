// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_bp/features/activities/activity_models.dart';
import 'package:smart_bp/features/activities/activity_provider.dart';

const Color _kVolunteerBlue = Color(0xFF1565C0);

/// 志工端：社區活動管理（新增 / 刪除，可上傳照片）。
class VolunteerActivitiesManagePage extends ConsumerWidget {
  const VolunteerActivitiesManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(communityEventsProvider);

    return Stack(
      children: [
        asyncList.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _kVolunteerBlue),
          ),
          error: (e, _) => _ErrorView(
            message: communityEventFriendlyError(e),
            onRetry: () => ref.read(communityEventsProvider.notifier).refresh(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return RefreshIndicator(
                color: _kVolunteerBlue,
                onRefresh: () =>
                    ref.read(communityEventsProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  children: const [
                    SizedBox(height: 80),
                    Icon(Icons.event_available_outlined,
                        size: 88, color: _kVolunteerBlue),
                    SizedBox(height: 24),
                    Text(
                      '尚無活動',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _kVolunteerBlue,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '點右下角「新增活動」發布社區活動，\n長輩就能在日曆上看到。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: _kVolunteerBlue,
              onRefresh: () =>
                  ref.read(communityEventsProvider.notifier).refresh(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _ManageEventCard(event: list[i]),
              ),
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            backgroundColor: _kVolunteerBlue,
            foregroundColor: Colors.white,
            onPressed: () => _openCreateForm(context, ref),
            icon: const Icon(Icons.add, size: 28),
            label: const Text(
              '新增活動',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreateForm(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ActivityFormSheet(parentRef: ref),
    );
  }
}

class _ManageEventCard extends ConsumerWidget {
  const _ManageEventCard({required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  event.photoUrl!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _PhotoFallback(),
                ),
              )
            else
              const _PhotoFallback(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${event.eventDate.month} 月 ${event.eventDate.day} 日'
                    '${event.startTime != null ? ' · ${event.startTime}' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kVolunteerBlue,
                    ),
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.location!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '刪除',
              icon: const Icon(Icons.delete_outline,
                  size: 26, color: Color(0xFFC62828)),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除活動',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: Text(
          '確定要刪除「${event.title}」嗎？\n刪除後長輩端日曆就看不到了。',
          style: const TextStyle(fontSize: 18, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            child: const Text('刪除', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(activityRepositoryProvider).delete(event.id);
      ref.invalidate(communityEventsProvider);
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: _kVolunteerBlue,
          content: Text('已刪除活動',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      print('[Activities] delete error: $e');
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBF360C),
          content: Text('刪除失敗：$e',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: _kVolunteerBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.event, size: 34, color: _kVolunteerBlue),
    );
  }
}

// ============================================================================
//  新增活動表單
// ============================================================================

class _ActivityFormSheet extends ConsumerStatefulWidget {
  const _ActivityFormSheet({required this.parentRef});

  final WidgetRef parentRef;

  @override
  ConsumerState<_ActivityFormSheet> createState() => _ActivityFormSheetState();
}

class _ActivityFormSheetState extends ConsumerState<_ActivityFormSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _eventDate;
  String? _photoPath;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: '選擇活動日期',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (picked != null && mounted) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (e) {
      print('[Activities] pick photo error: $e');
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

  String? _validate() {
    if (_titleController.text.trim().isEmpty) return '請輸入活動名稱';
    if (_eventDate == null) return '請選擇活動日期';
    return null;
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final err = _validate();
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBF360C),
          content: Text(err,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(activityRepositoryProvider).insert(
            title: _titleController.text,
            description: _descController.text,
            eventDate: _eventDate!,
            startTime: _timeController.text,
            location: _locationController.text,
            localPhotoPath: _photoPath,
          );
      widget.parentRef.invalidate(communityEventsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          content: Text('🎉 活動已發布，長輩端日曆會顯示！',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      print('[Activities] insert error: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBF360C),
          duration: const Duration(seconds: 5),
          content: Text('發布失敗：$e',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  String _formatDate(DateTime d) => '${d.year} 年 ${d.month} 月 ${d.day} 日';

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Stack(
          children: [
            ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '📅 新增社區活動',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kVolunteerBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel(icon: '📝', label: '活動名稱'),
                const SizedBox(height: 8),
                _TextField(
                  controller: _titleController,
                  hint: '例如：社區共餐 / 健康講座',
                ),
                const SizedBox(height: 20),
                const _FieldLabel(icon: '📅', label: '活動日期'),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _eventDate != null ? _kVolunteerBlue : Colors.black26,
                        width: _eventDate != null ? 2 : 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 24,
                            color: _eventDate != null
                                ? _kVolunteerBlue
                                : Colors.black54),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _eventDate != null
                                ? _formatDate(_eventDate!)
                                : '點此選擇日期',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _eventDate != null
                                  ? Colors.black87
                                  : Colors.black38,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel(icon: '⏰', label: '活動時間（可留空）'),
                const SizedBox(height: 8),
                _TextField(
                  controller: _timeController,
                  hint: '例如：上午 9:30',
                ),
                const SizedBox(height: 20),
                const _FieldLabel(icon: '📍', label: '活動地點（可留空）'),
                const SizedBox(height: 8),
                _TextField(
                  controller: _locationController,
                  hint: '例如：明德社區活動中心',
                ),
                const SizedBox(height: 20),
                const _FieldLabel(icon: '📝', label: '活動說明（可留空）'),
                const SizedBox(height: 8),
                _TextField(
                  controller: _descController,
                  hint: '活動內容、注意事項…',
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                const _FieldLabel(icon: '📷', label: '活動照片（可留空）'),
                const SizedBox(height: 8),
                _PhotoPicker(
                  photoPath: _photoPath,
                  onTap: _showPhotoSourceSheet,
                  onClear: () => setState(() => _photoPath = null),
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
                    child: const Text('✅ 發布活動',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Colors.black26, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('取消',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black26, width: 1.4),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 40, color: _kVolunteerBlue),
              SizedBox(height: 8),
              Text('點此上傳照片',
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
            height: 200,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 72, color: Color(0xFFBF360C)),
        const SizedBox(height: 16),
        Text(
          '讀取活動失敗：\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFBF360C),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 28),
          label: const Text('重新讀取',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: _kVolunteerBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}
