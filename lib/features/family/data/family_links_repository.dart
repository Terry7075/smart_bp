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

  Future<List<FamilyElderLink>> listMyLinks(String familyUserId) async {
    try {
      final raw = await _client
          .from('family_elder_links')
          .select('id, family_user_id, elder_user_id, relation, can_place_order, status')
          .eq('family_user_id', familyUserId)
          .eq('status', 'active')
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
    } catch (_) {
      return [];
    }
  }

  Future<void> bindElder({
    required String familyUserId,
    required String elderUserId,
    required String relation,
  }) async {
    await _client.from('family_elder_links').upsert({
      'family_user_id': familyUserId,
      'elder_user_id': elderUserId,
      'relation': relation.trim().isEmpty ? '家屬' : relation.trim(),
      'can_place_order': false,
      'status': 'active',
    }, onConflict: 'family_user_id,elder_user_id');
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
