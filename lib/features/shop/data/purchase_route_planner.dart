import 'dart:math' as math;

/// 地理點（採買路線用）。
final class GeoPoint {
  const GeoPoint({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.items = const [],
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<String> items;
}

/// 路線規劃結果。
final class PlannedRoute {
  const PlannedRoute({
    required this.algorithm,
    required this.totalDistanceKm,
    required this.stops,
  });

  final String algorithm;
  final double totalDistanceKm;
  final List<Map<String, dynamic>> stops;

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'total_distance_km': totalDistanceKm,
        'stops': stops,
      };
}

/// Nearest Neighbor 貪婪 TSP 近似。
class PurchaseRoutePlanner {
  const PurchaseRoutePlanner();

  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  PlannedRoute planNearestNeighbor({
    required GeoPoint start,
    required List<GeoPoint> stores,
    GeoPoint? returnHub,
  }) {
    final unvisited = List<GeoPoint>.from(stores);
    final ordered = <GeoPoint>[];
    var current = start;
    var totalKm = 0.0;

    while (unvisited.isNotEmpty) {
      var bestIdx = 0;
      var bestDist = double.infinity;
      for (var i = 0; i < unvisited.length; i++) {
        final d = haversineKm(
          current.lat,
          current.lng,
          unvisited[i].lat,
          unvisited[i].lng,
        );
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      totalKm += bestDist;
      current = unvisited.removeAt(bestIdx);
      ordered.add(current);
    }

    if (returnHub != null) {
      totalKm += haversineKm(
        current.lat,
        current.lng,
        returnHub.lat,
        returnHub.lng,
      );
      ordered.add(returnHub);
    }

    final stops = <Map<String, dynamic>>[];
    for (var i = 0; i < ordered.length; i++) {
      stops.add({
        'seq': i + 1,
        'location_id': ordered[i].id,
        'name': ordered[i].name,
        'lat': ordered[i].lat,
        'lng': ordered[i].lng,
        'items': ordered[i].items,
      });
    }

    return PlannedRoute(
      algorithm: 'nearest_neighbor_v1',
      totalDistanceKm: double.parse(totalKm.toStringAsFixed(2)),
      stops: stops,
    );
  }
}
