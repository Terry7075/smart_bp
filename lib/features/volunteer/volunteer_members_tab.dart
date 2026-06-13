import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/widgets/mindu_loading_overlay.dart';
import 'member_management.dart';

const Color _kVolunteerBlue = Color(0xFF1565C0);

/// 志工的「會員管理」Tab：列出所有長輩會員，可瀏覽並編輯姓名 / 電話 / 備註。
class VolunteerMembersTab extends ConsumerStatefulWidget {
  const VolunteerMembersTab({super.key});

  @override
  ConsumerState<VolunteerMembersTab> createState() =>
      _VolunteerMembersTabState();
}

class _VolunteerMembersTabState extends ConsumerState<VolunteerMembersTab> {
  String _query = '';

  List<ElderMember> _filter(List<ElderMember> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            (m.phone ?? '').toLowerCase().contains(q) ||
            (m.volunteerNote ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(elderMembersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '搜尋姓名 / 電話 / 備註',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('載入失敗：$e'),
                  TextButton(
                    onPressed: () => ref.invalidate(elderMembersProvider),
                    child: const Text('重試'),
                  ),
                ],
              ),
            ),
            data: (all) {
              if (all.isEmpty) {
                return const Center(child: Text('目前系統中尚無長輩帳號。'));
              }
              final list = _filter(all);
              return RefreshIndicator(
                color: _kVolunteerBlue,
                onRefresh: () async => ref.invalidate(elderMembersProvider),
                child: list.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('找不到符合的會員')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _MemberCard(
                          member: list[i],
                          onTap: () => _openEditor(list[i]),
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(ElderMember member) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberEditorSheet(member: member),
    );
    if (saved == true) {
      ref.invalidate(elderMembersProvider);
    }
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final ElderMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = member.volunteerNote;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      member.name.isNotEmpty ? member.name[0] : '?',
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              member.phone ?? '未填電話',
                              style: TextStyle(
                                fontSize: 13,
                                color: member.phone != null
                                    ? Colors.black87
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_note, color: _kVolunteerBlue),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 16, color: Color(0xFFF9A825)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 編輯長輩會員：姓名 / 電話 / 備註。
class _MemberEditorSheet extends ConsumerStatefulWidget {
  const _MemberEditorSheet({required this.member});

  final ElderMember member;

  @override
  ConsumerState<_MemberEditorSheet> createState() => _MemberEditorSheetState();
}

class _MemberEditorSheetState extends ConsumerState<_MemberEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.name);
    _phoneController = TextEditingController(text: widget.member.phone ?? '');
    _noteController =
        TextEditingController(text: widget.member.volunteerNote ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      await ref.read(memberManagementRepoProvider).updateElder(
            id: widget.member.id,
            name: _nameController.text,
            phone: _phoneController.text,
            note: _noteController.text,
          );
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('已儲存會員資料')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final created = widget.member.createdAt;

    return MinduLoadingOverlay(
      isLoading: _isSaving,
      message: '儲存中，請稍候...',
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.manage_accounts, color: _kVolunteerBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '編輯會員資料',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (created != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '加入時間：${DateFormat('yyyy/MM/dd').format(created)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: '姓名',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '請輸入姓名' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(fontSize: 18),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '電話',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '備註（所有志工可見）',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kVolunteerBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSaving ? null : _onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
