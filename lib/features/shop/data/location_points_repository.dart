import 'package:supabase_flutter/supabase_flutter.dart';

final class LocationPoint {
  const LocationPoint({
    required this.id,
    required this.name,
    this.address,
    this.contactPhone,
  });

  final String id;
  final String name;
  final String? address;
  final String? contactPhone;
}

final class LocationAsset {
  const LocationAsset({
    required this.id,
    required this.locationPointId,
    required this.itemName,
    required this.quantity,
    this.notes,
    this.locationName,
  });

  final String id;
  final String locationPointId;
  final String itemName;
  final int quantity;
  final String? notes;
  final String? locationName;
}

final class LocationPointsRepository {
  const LocationPointsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<LocationPoint>> listPoints() async {
    try {
      final raw = await _client
          .from('location_points')
          .select()
          .order('name');
      return List<dynamic>.from(raw as List? ?? const []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return LocationPoint(
          id: m['id']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          address: m['address']?.toString(),
          contactPhone: m['contact_phone']?.toString(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<LocationAsset>> listAssets() async {
    try {
      final raw = await _client
          .from('location_assets')
          .select('id, location_point_id, item_name, quantity, notes, location_points(name)')
          .order('item_name');
      return List<dynamic>.from(raw as List? ?? const []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final loc = m['location_points'];
        return LocationAsset(
          id: m['id']?.toString() ?? '',
          locationPointId: m['location_point_id']?.toString() ?? '',
          itemName: m['item_name']?.toString() ?? '',
          quantity: (m['quantity'] as num?)?.toInt() ?? 0,
          notes: m['notes']?.toString(),
          locationName: loc is Map ? loc['name']?.toString() : null,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
