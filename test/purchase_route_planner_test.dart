import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/purchase_route_planner.dart';

void main() {
  test('Nearest Neighbor 產出有序站點', () {
    const planner = PurchaseRoutePlanner();
    final route = planner.planNearestNeighbor(
      start: const GeoPoint(id: 's', name: '起點', lat: 24.56, lng: 120.82),
      stores: [
        const GeoPoint(id: '1', name: '店A', lat: 24.57, lng: 120.81),
        const GeoPoint(id: '2', name: '店B', lat: 24.58, lng: 120.83),
      ],
      returnHub: const GeoPoint(id: 'h', name: '據點', lat: 24.564, lng: 120.8215),
    );
    expect(route.stops.length, greaterThanOrEqualTo(2));
    expect(route.totalDistanceKm, greaterThan(0));
    expect(route.algorithm, 'nearest_neighbor_v1');
  });
}
