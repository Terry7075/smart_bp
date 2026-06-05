import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/learning/learning_content_models.dart';
import 'package:smart_bp/features/learning/learning_content_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _kManageBlue = Color(0xFF1565C0);

/// 志工端：社區學習／客語內容發布管理。
class VolunteerContentManagePage extends ConsumerWidget {
  const VolunteerContentManagePage({super.key, this.embedded = false});

  /// 嵌入志工端主畫面時為 true，不另包一層 [Scaffold]／[AppBar]。
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(learningContentProvider);

    final listBody = asyncList.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '讀取失敗：\n${learningContentFriendlyError(e)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 64,
                child: FilledButton(
                  onPressed: () =>
                      ref.read(learningContentProvider.notifier).refresh(),
                  child: const Text(
                    '再試一次',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text(
              '尚無內容，請點右下角「+」新增。',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = list[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${LearningCategory.label(item.category)} · '
                    '${LearningContentType.label(item.contentType)}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 28),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _openEditor(context, ref, existing: item);
                    } else if (value == 'delete') {
                      final ok = await _confirmDelete(context, item.title);
                      if (ok && context.mounted) {
                        await ref
                            .read(learningContentRepositoryProvider)
                            .delete(item.id);
                        ref.invalidate(learningContentProvider);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        '編輯',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        '刪除',
                        style: TextStyle(
                          fontSize: 20,
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final fab = FloatingActionButton.extended(
      onPressed: () => _openEditor(context, ref),
      backgroundColor: _kManageBlue,
      icon: const Icon(Icons.add, size: 28),
      label: const Text(
        '新增內容',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );

    if (embedded) {
      return RoleGuard(
        requiredRole: RoleGuardTarget.volunteer,
        child: Stack(
          children: [
            Positioned.fill(child: listBody),
            Positioned(right: 16, bottom: 16, child: fab),
          ],
        ),
      );
    }

    return RoleGuard(
      requiredRole: RoleGuardTarget.volunteer,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8E1),
        appBar: AppBar(
          backgroundColor: _kManageBlue,
          foregroundColor: Colors.white,
          toolbarHeight: 72,
          title: const Text(
            '學習內容管理',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        floatingActionButton: fab,
        body: listBody,
      ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '確定刪除？',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '「$title」刪除後長輩端將不再顯示。',
          style: const TextStyle(fontSize: 20, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(fontSize: 20)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static void _openEditor(
    BuildContext context,
    WidgetRef ref, {
    LearningContent? existing,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ContentEditorSheet(
        existing: existing,
        onSaved: () => Navigator.pop(ctx),
      ),
    );
  }
}

class _ContentEditorSheet extends ConsumerStatefulWidget {
  const _ContentEditorSheet({
    required this.onSaved,
    this.existing,
  });

  final LearningContent? existing;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ContentEditorSheet> createState() => _ContentEditorSheetState();
}

class _ContentEditorSheetState extends ConsumerState<_ContentEditorSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  late String _category;
  late String _contentType;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? LearningCategory.antiFraud;
    _contentType = e?.contentType ?? LearningContentType.video;
    _titleCtrl.text = e?.title ?? '';
    _descCtrl.text = e?.description ?? '';
    _urlCtrl.text = e?.url ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (title.isEmpty) {
      _toast('請輸入標題');
      return;
    }
    if (url.isEmpty) {
      _toast('請輸入網址');
      return;
    }
    if (_contentType == LearningContentType.video &&
        youtubeVideoIdFromUrl(url) == null) {
      _toast('影片請貼上有效的 YouTube 連結');
      return;
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _toast('請先登入');
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(learningContentRepositoryProvider);
      final desc = _descCtrl.text.trim();
      if (widget.existing != null) {
        await repo.update(
          id: widget.existing!.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          category: _category,
          contentType: _contentType,
          url: url,
        );
      } else {
        await repo.insert(
          LearningContent(
            id: '',
            createdAt: DateTime.now(),
            title: title,
            description: desc.isEmpty ? null : desc,
            category: _category,
            contentType: _contentType,
            url: url,
          ),
          volunteerId: uid,
        );
      }
      ref.invalidate(learningContentProvider);
      if (!mounted) return;
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existing != null ? '已更新內容' : '已發布內容',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      _toast('儲存失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing != null ? '編輯內容' : '新增內容',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _inputDeco('分類'),
              style: const TextStyle(fontSize: 20, color: Colors.black87),
              items: [
                for (final c in LearningCategory.all)
                  DropdownMenuItem(
                    value: c,
                    child: Text(LearningCategory.label(c)),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            const Text(
              '內容類型',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: LearningContentType.video,
                  label: Text('影片', style: TextStyle(fontSize: 18)),
                  icon: Icon(Icons.play_circle_outline),
                ),
                ButtonSegment(
                  value: LearningContentType.article,
                  label: Text('文章', style: TextStyle(fontSize: 18)),
                  icon: Icon(Icons.article_outlined),
                ),
              ],
              selected: {_contentType},
              onSelectionChanged: _busy
                  ? null
                  : (set) => setState(() => _contentType = set.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 22),
              decoration: _inputDeco('標題'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(fontSize: 20),
              maxLines: 3,
              decoration: _inputDeco('說明（選填）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              style: const TextStyle(fontSize: 20),
              keyboardType: TextInputType.url,
              decoration: _inputDeco(
                _contentType == LearningContentType.video
                    ? 'YouTube 影片網址'
                    : '文章網址',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 64,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: _kManageBlue),
                child: _busy
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text(
                        widget.existing != null ? '儲存變更' : '發布',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }
}
