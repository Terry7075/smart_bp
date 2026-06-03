import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/profile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  var _signingOut = false;

  Future<void> _confirmAndSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('登出後需要重新使用 Google 登入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('登出'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) return;

    setState(() => _signingOut = true);
    final authService = ref.read(authServiceProvider);
    try {
      await authService.signOut();
      if (!mounted) return;
      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentDriverApplicationProvider);
      ref.invalidate(myRideRequestsProvider);
      ref.invalidate(myNotificationsProvider);
      context.go('/login');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: profileState.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('尚未建立個人資料'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(profile: profile),
                const SizedBox(height: 20),
                _InfoCard(profile: profile),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.push('/profile/setup'),
                  icon: const Icon(Icons.edit),
                  label: const Text('編輯個人資料'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _signingOut ? null : _confirmAndSignOut,
                  icon: _signingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: Text(_signingOut ? '登出中...' : '登出'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀取個人資料失敗：$error')),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final name =
        profile.fullName?.trim().isNotEmpty == true ? profile.fullName! : '未命名';
    final avatarUrl = profile.avatarUrl?.trim();

    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundImage: avatarUrl == null || avatarUrl.isEmpty
              ? null
              : NetworkImage(avatarUrl),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(name.characters.first,
                  style: Theme.of(context).textTheme.headlineMedium)
              : null,
        ),
        const SizedBox(height: 12),
        Text(name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(profile.roleLabel, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _InfoRow(icon: Icons.email, label: 'Email', value: profile.email),
            const Divider(height: 28),
            _InfoRow(
                icon: Icons.phone, label: '電話', value: profile.phone ?? '未填寫'),
            const Divider(height: 28),
            _InfoRow(icon: Icons.badge, label: '角色', value: profile.roleLabel),
            const Divider(height: 28),
            _InfoRow(
              icon: Icons.emergency,
              label: '緊急聯絡人',
              value: _emergencyContactText(profile),
            ),
          ],
        ),
      ),
    );
  }

  String _emergencyContactText(Profile profile) {
    final name = profile.emergencyContactName;
    final phone = profile.emergencyContactPhone;
    final relation = profile.emergencyContactRelation;
    if ((name == null || name.isEmpty) && (phone == null || phone.isEmpty)) {
      return '未填寫';
    }
    return [
      if (name != null && name.isNotEmpty) name,
      if (relation != null && relation.isNotEmpty) relation,
      if (phone != null && phone.isNotEmpty) phone,
    ].join(' / ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}
