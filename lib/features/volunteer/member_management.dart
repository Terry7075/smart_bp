import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_provider.dart';

/// 一位長輩(elder)的會員資料，供志工瀏覽與編輯。
class ElderMember {
  const ElderMember({
    required this.id,
    required this.name,
    this.phone,
    this.points,
    this.createdAt,
    this.volunteerNote,
  });

  final String id;
  final String name;
  final String? phone;
  final int? points;
  final DateTime? createdAt;
  final String? volunteerNote;

  factory ElderMember.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    return ElderMember(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : '(未命名)',
      phone: (map['phone'] as String?)?.trim().isNotEmpty == true
          ? (map['phone'] as String).trim()
          : null,
      points: (map['points'] as num?)?.toInt(),
      createdAt: createdRaw is String ? DateTime.tryParse(createdRaw) : null,
      volunteerNote: (map['volunteer_note'] as String?)?.trim().isNotEmpty == true
          ? (map['volunteer_note'] as String).trim()
          : null,
    );
  }
}

/// 志工會員管理資料存取層。
///
/// 讀取沿用既有 `profiles_select_staff` RLS（志工/管理員可讀全部 profiles）；
/// 寫入則透過 SECURITY DEFINER RPC `volunteer_update_elder_member`，
/// 僅能更新 elder 的姓名 / 電話 / 備註，無法竄改角色。
class MemberManagementRepository {
  MemberManagementRepository(this._client);

  final SupabaseClient _client;

  Future<List<ElderMember>> fetchElders() async {
    final rows = await _client
        .from('profiles')
        .select('id, name, phone, points, created_at, volunteer_note')
        .eq('role', 'elder')
        .order('name');

    return (rows as List)
        .map((r) => ElderMember.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> updateElder({
    required String id,
    required String name,
    String? phone,
    String? note,
  }) async {
    await _client.rpc('volunteer_update_elder_member', params: {
      'p_target_id': id,
      'p_name': name,
      'p_phone': phone,
      'p_note': note,
    });
  }
}

final memberManagementRepoProvider =
    Provider<MemberManagementRepository>((ref) {
  return MemberManagementRepository(Supabase.instance.client);
});

/// 志工：所有長輩會員清單（手動 refresh；資料量小可接受）。
final elderMembersProvider =
    FutureProvider.autoDispose<List<ElderMember>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.read(memberManagementRepoProvider).fetchElders();
});
