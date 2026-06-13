import 'package:supabase_flutter/supabase_flutter.dart';

final class FamilyElderLink {
  const FamilyElderLink({
    required this.id,
    required this.familyUserId,
    required this.elderUserId,
    required this.relation,
    required this.canPlaceOrder,
    required this.status,
    this.elderName,
  });

  final String id;
  final String familyUserId;
  final String elderUserId;
  final String relation;
  final bool canPlaceOrder;
  final String status;
  final String? elderName;

  factory FamilyElderLink.fromMap(Map<String, dynamic> m) {
    return FamilyElderLink(
      id: m['id']?.toString() ?? '',
      familyUserId: m['family_user_id']?.toString() ?? '',
      elderUserId: m['elder_user_id']?.toString() ?? '',
      relation: m['relation']?.toString() ?? '家屬',
      canPlaceOrder: m['can_place_order'] == true,
      status: m['status']?.toString() ?? 'active',
      elderName: m['elder_name']?.toString(),
    );
  }
}

final class FamilyLinksRepository {
  const FamilyLinksRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// 家屬端：列出我建立的綁定（含 pending 等待長者確認 / active 已生效）。
  Future<List<FamilyElderLink>> listMyLinks(String familyUserId) async {
    final raw = await _client
        .from('family_elder_links')
        .select('id, family_user_id, elder_user_id, relation, can_place_order, status')
        .eq('family_user_id', familyUserId)
        .neq('status', 'rejected')
        .order('created_at', ascending: false);

    final links = <FamilyElderLink>[];
    final elderIds = <String>{};
    for (final e in List<dynamic>.from(raw as List? ?? const [])) {
      if (e is! Map) continue;
      final link = FamilyElderLink.fromMap(Map<String, dynamic>.from(e));
      links.add(link);
      elderIds.add(link.elderUserId);
    }

    final names = await _fetchNames(elderIds);
    return links
        .map(
          (l) => FamilyElderLink(
            id: l.id,
            familyUserId: l.familyUserId,
            elderUserId: l.elderUserId,
            relation: l.relation,
            canPlaceOrder: l.canPlaceOrder,
            status: l.status,
            elderName: names[l.elderUserId],
          ),
        )
        .toList();
  }

  /// 長者端：列出待我確認的綁定請求（status='pending'）。
  Future<List<FamilyElderLink>> listPendingForElder(String elderUserId) async {
    final raw = await _client
        .from('family_elder_links')
        .select('id, family_user_id, elder_user_id, relation, can_place_order, status')
        .eq('elder_user_id', elderUserId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<dynamic>.from(raw as List? ?? const [])
        .whereType<Map>()
        .map((e) => FamilyElderLink.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// 家屬端：送出綁定請求（status='pending'，需長者於 App 內同意後才生效）。
  ///
  /// 為避免重複請求需要 UPDATE 權限（會讓家屬有機會自行改狀態），這裡用
  /// `ignoreDuplicates`：若已有同一對 (家屬, 長者) 的列就不動作。
  Future<void> requestBind({
    required String familyUserId,
    required String elderUserId,
    required String relation,
  }) async {
    final target = elderUserId.trim();
    if (!_uuidRe.hasMatch(target)) {
      throw ArgumentError('長輩使用者 ID 格式不正確，請確認是完整的 UUID。');
    }
    if (target == familyUserId) {
      throw ArgumentError('不能綁定自己的帳號。');
    }
    await _client.from('family_elder_links').upsert({
      'family_user_id': familyUserId,
      'elder_user_id': target,
      'relation': relation.trim().isEmpty ? '家屬' : relation.trim(),
      'can_place_order': false,
      'status': 'pending',
    }, onConflict: 'family_user_id,elder_user_id', ignoreDuplicates: true);
  }

  /// 長者端：同意綁定請求 → status='active'。
  Future<void> approveLink(String linkId) async {
    await _client
        .from('family_elder_links')
        .update({'status': 'active'}).eq('id', linkId);
  }

  /// 長者端：拒絕綁定請求 → 刪除該列（家屬可日後重新送出）。
  Future<void> rejectLink(String linkId) async {
    await _client.from('family_elder_links').delete().eq('id', linkId);
  }

  Future<Map<String, String>> _fetchNames(Set<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final res = await _client
          .from('profiles')
          .select('id,name')
          .inFilter('id', ids.toList());
      final map = <String, String>{};
      for (final e in List<dynamic>.from(res as List? ?? const [])) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = m['id']?.toString();
        final name = m['name']?.toString().trim();
        if (id != null && name != null && name.isNotEmpty) map[id] = name;
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
