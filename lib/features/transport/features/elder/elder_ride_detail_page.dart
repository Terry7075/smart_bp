import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../models/driver.dart';
import '../../models/ride_match.dart';
import '../../models/ride_request.dart';
import '../../models/ride_status.dart';
import '../../services/ride_service.dart';
import '../../widgets/driver_location_map.dart';

class ElderRideDetailPage extends ConsumerStatefulWidget {
  const ElderRideDetailPage({super.key, required this.rideRequestId});

  final String rideRequestId;

  @override
  ConsumerState<ElderRideDetailPage> createState() =>
      _ElderRideDetailPageState();
}

class _ElderRideDetailPageState extends ConsumerState<ElderRideDetailPage> {
  late Future<_RideDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRideDetail(ref.read(rideServiceProvider));
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadRideDetail(ref.read(rideServiceProvider));
    });
    ref.invalidate(driverLocationForRideProvider(widget.rideRequestId));
    ref.invalidate(feedbackForRideProvider(widget.rideRequestId));
  }

  Future<void> _cancelRide() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消行程'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: '取消原因（選填）'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('返回')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('取消行程')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(rideServiceProvider).cancelRideRequest(
          rideRequestId: widget.rideRequestId,
          reason: reasonController.text,
        );
    await _refresh();
  }

  Future<void> _submitRating() async {
    var rating = 5;
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('行程評分'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: '評分'),
                items: List.generate(5, (index) => index + 1)
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text('$value 分')))
                    .toList(),
                onChanged: (value) => setDialogState(() => rating = value ?? 5),
              ),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(labelText: '留言（選填）'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('送出')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(feedbackServiceProvider).submitFeedback(
          rideRequestId: widget.rideRequestId,
          rating: rating,
          comment: commentController.text,
        );
    ref.invalidate(feedbackForRideProvider(widget.rideRequestId));
  }

  Future<void> _reportIssue() async {
    final issueController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('問題回報'),
        content: TextField(
          controller: issueController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '請描述遇到的問題'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('送出')),
        ],
      ),
    );
    if (confirmed != true || issueController.text.trim().isEmpty) return;
    await ref.read(feedbackServiceProvider).submitFeedback(
          rideRequestId: widget.rideRequestId,
          issueType: 'user_report',
          issueDescription: issueController.text,
        );
    ref.invalidate(feedbackForRideProvider(widget.rideRequestId));
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    await ref.read(driverActionServiceProvider).callPhone(phone);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final location =
        ref.watch(driverLocationForRideProvider(widget.rideRequestId));
    final feedback = ref.watch(feedbackForRideProvider(widget.rideRequestId));

    return Scaffold(
      appBar: AppBar(title: const Text('行程詳情')),
      body: FutureBuilder<_RideDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ride = snapshot.data!.ride;
          final driver = snapshot.data!.driver;
          if (ride == null) return const Center(child: Text('找不到行程'));

          final canCancel = ride.status == RideStatus.pending ||
              ride.status == RideStatus.matched;
          final canRate = ride.status == RideStatus.completed;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(ride.status.label,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
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
                  error: (error, _) => Text('GPS 讀取失敗：$error'),
                ),
                const SizedBox(height: 16),
                _InfoLine(label: '目的地', value: ride.displayDestination),
                _InfoLine(label: '上車點', value: ride.pickupLocation),
                _InfoLine(
                  label: '日期',
                  value: DateFormat('yyyy/MM/dd').format(ride.rideDate),
                ),
                _InfoLine(label: '時間', value: ride.rideTime.substring(0, 5)),
                _InfoLine(label: '乘客數', value: '${ride.passengerCount}'),
                _InfoLine(
                  label: '費用',
                  value: ride.estimatedPrice == null
                      ? '媒合後估算'
                      : '${ride.estimatedPrice} 元',
                ),
                const SizedBox(height: 16),
                if (driver == null)
                  const Text('尚未媒合司機')
                else ...[
                  Text('司機資訊', style: Theme.of(context).textTheme.titleMedium),
                  _InfoLine(label: '姓名', value: driver.name),
                  _InfoLine(label: '電話', value: driver.phone),
                  _InfoLine(label: '車牌', value: driver.carPlate),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          driver == null ? null : () => _call(driver.phone),
                      icon: const Icon(Icons.phone),
                      label: const Text('撥打司機'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _call(profile?.emergencyContactPhone),
                      icon: const Icon(Icons.emergency),
                      label: const Text('緊急聯絡人'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _call(AppConstants.operationsPhone),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('管理員'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (canCancel)
                  FilledButton.icon(
                    onPressed: _cancelRide,
                    icon: const Icon(Icons.cancel),
                    label: const Text('取消行程'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                if (canRate) ...[
                  FilledButton.icon(
                    onPressed: _submitRating,
                    icon: const Icon(Icons.star),
                    label: const Text('評分'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _reportIssue,
                  icon: const Icon(Icons.report_problem),
                  label: const Text('問題回報'),
                ),
                const SizedBox(height: 20),
                feedback.when(
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('回饋紀錄',
                                style: Theme.of(context).textTheme.titleMedium),
                            ...items.map((item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                      item.isIssue ? Icons.report : Icons.star),
                                  title: Text(item.isIssue
                                      ? item.issueType ?? '問題回報'
                                      : '${item.rating} 分'),
                                  subtitle: Text(item.issueDescription ??
                                      item.comment ??
                                      ''),
                                )),
                          ],
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (error, _) => Text('回饋讀取失敗：$error'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_RideDetailData> _loadRideDetail(RideService service) async {
    final ride = await service.fetchRideRequestById(widget.rideRequestId);
    final match = await service.fetchMatchForRideRequest(widget.rideRequestId);
    final driver =
        match == null ? null : await service.fetchDriverById(match.driverId);
    return _RideDetailData(ride: ride, match: match, driver: driver);
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label：$value'),
    );
  }
}

class _RideDetailData {
  const _RideDetailData(
      {required this.ride, required this.match, required this.driver});

  final RideRequest? ride;
  final RideMatch? match;
  final Driver? driver;
}
