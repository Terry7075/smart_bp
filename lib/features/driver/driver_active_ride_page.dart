import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/profile.dart';
import '../../models/ride_request.dart';
import '../../models/ride_status.dart';
import '../../widgets/driver_location_map.dart';

class DriverActiveRidePage extends ConsumerStatefulWidget {
  const DriverActiveRidePage({
    super.key,
    required this.matchId,
    required this.rideRequestId,
  });

  final String matchId;
  final String rideRequestId;

  @override
  ConsumerState<DriverActiveRidePage> createState() => _DriverActiveRidePageState();
}

class _DriverActiveRidePageState extends ConsumerState<DriverActiveRidePage> {
  late Future<_ActiveRideData> _future;
  RideStatus? _localStatus;
  String? _trackingError;

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
  }

  @override
  void dispose() {
    ref.read(locationTrackingServiceProvider).stopTracking();
    super.dispose();
  }

  Future<_ActiveRideData> _load() async {
    final service = ref.read(rideServiceProvider);
    final ride = await service.fetchRideRequestById(widget.rideRequestId);
    final elder = ride == null ? null : await service.fetchProfileById(ride.elderId);
    _localStatus ??= ride?.status;
    return _ActiveRideData(ride: ride, elder: elder);
  }

  Future<void> _startTracking() async {
    try {
      await ref.read(locationTrackingServiceProvider).startForegroundTracking(widget.matchId);
      if (mounted) setState(() => _trackingError = null);
    } catch (error) {
      if (mounted) setState(() => _trackingError = '$error');
    }
  }

  Future<void> _update(RideStatus status) async {
    await ref.read(rideServiceProvider).updateMatchStatus(matchId: widget.matchId, status: status);
    if (status == RideStatus.completed) {
      ref.read(locationTrackingServiceProvider).stopTracking();
    }
    setState(() => _localStatus = status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('行程狀態已更新：${status.label}')),
      );
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    await ref.read(driverActionServiceProvider).callPhone(phone);
  }

  Future<void> _navigateTo(RideRequest ride) async {
    await ref.read(driverActionServiceProvider).openNavigation(ride.displayDestination);
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(driverLocationForRideProvider(widget.rideRequestId));

    return Scaffold(
      appBar: AppBar(title: const Text('進行中任務')),
      body: FutureBuilder<_ActiveRideData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final ride = snapshot.data!.ride;
          final elder = snapshot.data!.elder;
          if (ride == null) return const Center(child: Text('找不到任務'));

          final status = _localStatus ?? ride.status;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ride.displayDestination, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('目前狀態：${status.label}'),
                const SizedBox(height: 12),
                location.when(
                  data: (item) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DriverLocationMap(location: item),
                      const SizedBox(height: 8),
                      DriverLocationStatus(location: item),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('GPS 顯示失敗：$error'),
                ),
                if (_trackingError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '定位未啟用：$_trackingError',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Text('上車點：${ride.pickupLocation}'),
                Text('乘客數：${ride.passengerCount}'),
                if (ride.needReturn) Text('需要回程：${ride.returnTime?.substring(0, 5) ?? '未指定'}'),
                if (ride.note != null) Text('備註：${ride.note}'),
                if (elder != null) ...[
                  const SizedBox(height: 12),
                  Text('乘客：${elder.fullName ?? elder.email}'),
                  Text('電話：${elder.phone ?? '未填寫'}'),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _call(elder?.phone),
                      icon: const Icon(Icons.phone),
                      label: const Text('撥打乘客'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _navigateTo(ride),
                      icon: const Icon(Icons.navigation),
                      label: const Text('導航'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: status == RideStatus.matched
                      ? () => _update(RideStatus.pickedUp)
                      : null,
                  child: const Text('接到人'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: status == RideStatus.pickedUp
                      ? () => _update(RideStatus.completed)
                      : null,
                  child: const Text('已送達'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActiveRideData {
  const _ActiveRideData({required this.ride, required this.elder});

  final RideRequest? ride;
  final Profile? elder;
}
