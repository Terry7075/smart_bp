import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/driver_location.dart';

class DriverLocationMap extends StatelessWidget {
  const DriverLocationMap({
    super.key,
    required this.location,
    this.height = 220,
  });

  final DriverLocation? location;
  final double height;

  @override
  Widget build(BuildContext context) {
    final current = location;
    if (current == null) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('尚未收到司機 GPS 位置'),
      );
    }

    final point = LatLng(current.latitude, current.longitude);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'tw.mingde.transport',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 48,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.local_taxi,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DriverLocationStatus extends StatelessWidget {
  const DriverLocationStatus({super.key, required this.location});

  final DriverLocation? location;

  @override
  Widget build(BuildContext context) {
    final current = location;
    if (current == null) return const Text('GPS 尚未更新');

    final seconds = DateTime.now().difference(current.updatedAt).inSeconds;
    final stale = seconds > 60;
    return Text(
      stale ? 'GPS 可能延遲，最後更新 ${seconds}s 前' : 'GPS ${seconds}s 前更新',
      style: TextStyle(
        color: stale ? Theme.of(context).colorScheme.error : null,
        fontWeight: stale ? FontWeight.w600 : null,
      ),
    );
  }
}
