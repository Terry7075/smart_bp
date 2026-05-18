import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/driver.dart';
import '../../models/ride_feedback.dart';
import '../../models/ride_match.dart';
import '../../models/ride_request.dart';
import '../../models/ride_status.dart';
import '../../widgets/driver_location_map.dart';

class AdminLiveRidesPage extends ConsumerWidget {
  const AdminLiveRidesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(todayRidesProvider);
    final drivers = ref.watch(approvedDriversProvider);
    final issues = ref.watch(unresolvedIssuesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('即時調度')),
      body: rides.when(
        data: (items) => drivers.when(
          data: (driverItems) => issues.when(
            data: (issueItems) => items.isEmpty
                ? const Center(child: Text('今天沒有行程'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final ride = items[index];
                      final rideIssues = issueItems
                          .where((issue) => issue.rideRequestId == ride.id)
                          .toList();
                      return _LiveRideCard(
                        ride: ride,
                        drivers: driverItems,
                        issues: rideIssues,
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('讀取問題回報失敗：$error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('讀取司機失敗：$error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀取行程失敗：$error')),
      ),
    );
  }
}

class _LiveRideCard extends ConsumerStatefulWidget {
  const _LiveRideCard({
    required this.ride,
    required this.drivers,
    required this.issues,
  });

  final RideRequest ride;
  final List<Driver> drivers;
  final List<RideFeedback> issues;

  @override
  ConsumerState<_LiveRideCard> createState() => _LiveRideCardState();
}

class _LiveRideCardState extends ConsumerState<_LiveRideCard> {
  late Future<_AdminRideDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AdminRideDetail> _load() async {
    final service = ref.read(rideServiceProvider);
    final match = await service.fetchMatchForRideRequest(widget.ride.id);
    final driver = match == null ? null : await service.fetchDriverById(match.driverId);
    return _AdminRideDetail(match: match, driver: driver);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    ref.invalidate(todayRidesProvider);
    ref.invalidate(unresolvedIssuesProvider);
    ref.invalidate(driverLocationForRideProvider(widget.ride.id));
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消行程'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: '原因'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('返回')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('取消行程')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(rideServiceProvider).cancelRideRequest(
          rideRequestId: widget.ride.id,
          reason: reasonController.text,
        );
    await _reload();
  }

  Future<void> _reschedule() async {
    var date = widget.ride.rideDate;
    var time = _parseTime(widget.ride.rideTime);
    final dateResult = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (dateResult == null || !mounted) return;
    date = dateResult;
    final timeResult = await showTimePicker(context: context, initialTime: time);
    if (timeResult == null) return;
    time = timeResult;

    await ref.read(rideServiceProvider).rescheduleRideRequest(
          rideRequestId: widget.ride.id,
          rideDate: date,
          rideTime: _formatTime(time),
          returnTime: widget.ride.returnTime,
        );
    await _reload();
  }

  Future<void> _reassign() async {
    Driver? selected;
    final candidates = widget.drivers
        .where((driver) => driver.maxPassengers >= widget.ride.passengerCount)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('改派司機'),
          content: DropdownButtonFormField<Driver>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: '選擇司機'),
            items: candidates
                .map((driver) => DropdownMenuItem(
                      value: driver,
                      child: Text('${driver.name} / ${driver.maxPassengers} 人'),
                    ))
                .toList(),
            onChanged: (value) => setDialogState(() => selected = value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.of(context).pop(true),
              child: const Text('改派'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selected == null) return;
    await ref.read(rideServiceProvider).reassignRide(
          rideRequestId: widget.ride.id,
          newDriverId: selected!.id,
        );
    await _reload();
  }

  Future<void> _resolveIssue(String feedbackId) async {
    await ref.read(feedbackServiceProvider).resolveFeedback(feedbackId);
    ref.invalidate(unresolvedIssuesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(driverLocationForRideProvider(widget.ride.id));
    final canOperate = widget.ride.status != RideStatus.completed &&
        widget.ride.status != RideStatus.cancelled;
    final delayed = _isDelayed(widget.ride);

    return FutureBuilder<_AdminRideDetail>(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.ride.displayDestination,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text(widget.ride.status.label)),
                  ],
                ),
                if (delayed)
                  Text(
                    '可能延誤',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text('時間：${DateFormat('yyyy/MM/dd').format(widget.ride.rideDate)} ${widget.ride.rideTime.substring(0, 5)}'),
                Text('上車：${widget.ride.pickupLocation}'),
                Text('乘客數：${widget.ride.passengerCount}'),
                Text('司機：${detail?.driver?.name ?? '尚未媒合'}'),
                const SizedBox(height: 12),
                location.when(
                  data: (item) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DriverLocationMap(location: item, height: 180),
                      const SizedBox(height: 8),
                      DriverLocationStatus(location: item),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('GPS 讀取失敗：$error'),
                ),
                if (widget.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('未處理問題', style: Theme.of(context).textTheme.titleMedium),
                  ...widget.issues.map((issue) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.report_problem),
                        title: Text(issue.issueType ?? '問題回報'),
                        subtitle: Text(issue.issueDescription ?? ''),
                        trailing: TextButton(
                          onPressed: () => _resolveIssue(issue.id),
                          child: const Text('已處理'),
                        ),
                      )),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canOperate ? _reschedule : null,
                      icon: const Icon(Icons.event),
                      label: const Text('改期'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canOperate ? _reassign : null,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('改派'),
                    ),
                    FilledButton.icon(
                      onPressed: canOperate ? _cancel : null,
                      icon: const Icon(Icons.cancel),
                      label: const Text('取消'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isDelayed(RideRequest ride) {
    if (ride.status == RideStatus.completed || ride.status == RideStatus.cancelled) {
      return false;
    }
    final parts = ride.rideTime.split(':');
    final scheduled = DateTime(
      ride.rideDate.year,
      ride.rideDate.month,
      ride.rideDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return DateTime.now().difference(scheduled).inMinutes > 30;
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
}

class _AdminRideDetail {
  const _AdminRideDetail({required this.match, required this.driver});

  final RideMatch? match;
  final Driver? driver;
}
