import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../models/driver_standing_ride_offer.dart';
import '../../models/standing_ride_weekdays.dart';

class CreateDriverStandingRideOfferPage extends ConsumerStatefulWidget {
  const CreateDriverStandingRideOfferPage({super.key});

  @override
  ConsumerState<CreateDriverStandingRideOfferPage> createState() =>
      _CreateDriverStandingRideOfferPageState();
}

class _CreateDriverStandingRideOfferPageState
    extends ConsumerState<CreateDriverStandingRideOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _customPickupController = TextEditingController();
  final _customDestinationController = TextEditingController();
  final _noteController = TextEditingController();
  var _pickupLocation = AppConstants.pickupLocations.first;
  var _destination = AppConstants.destinations.first;
  var _rideTime = const TimeOfDay(hour: 8, minute: 0);
  var _needReturn = false;
  TimeOfDay? _returnTime;
  var _passengerCount = 1;
  final _serviceWeekdays = <int>{
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };
  var _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;
  var _saving = false;

  @override
  void dispose() {
    _customPickupController.dispose();
    _customDestinationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime({required bool isReturn}) async {
    final result = await showTimePicker(
      context: context,
      initialTime: isReturn ? (_returnTime ?? _rideTime) : _rideTime,
    );
    if (result == null) return;
    setState(() {
      if (isReturn) {
        _returnTime = result;
      } else {
        _rideTime = result;
      }
    });
  }

  Future<void> _pickDate({required bool isEndDate}) async {
    final result = await showDatePicker(
      context: context,
      initialDate: isEndDate ? (_endDate ?? _startDate) : _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result == null) return;
    setState(() {
      if (isEndDate) {
        _endDate = result;
      } else {
        _startDate = result;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少選擇一個服務星期')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final pickup = _pickupLocation == AppConstants.customPickupLocation
          ? _customPickupController.text.trim()
          : _pickupLocation;
      await ref.read(standingRideServiceProvider).createDriverStandingRideOffer(
            pickupLocation: pickup,
            destination: _destination,
            customDestination: _destination == AppConstants.customDestination
                ? _customDestinationController.text.trim()
                : null,
            rideTime: _formatTime(_rideTime),
            passengerCount: _passengerCount,
            needReturn: _needReturn,
            returnTime: _needReturn && _returnTime != null
                ? _formatTime(_returnTime!)
                : null,
            note: _noteController.text,
            serviceWeekdays: normalizeServiceWeekdays(_serviceWeekdays),
            startDate: _startDate,
            endDate: _endDate,
          );
      ref.invalidate(myDriverStandingRideOffersProvider);
      if (mounted) context.go('/transport/driver');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送出失敗：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(myDriverStandingRideOffersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('刊登長期接送')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _pickupLocation,
                  decoration: const InputDecoration(labelText: '上車地點'),
                  items: AppConstants.pickupLocations
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _pickupLocation = value!),
                ),
                if (_pickupLocation == AppConstants.customPickupLocation) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customPickupController,
                    decoration: const InputDecoration(labelText: '自訂上車地點'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '請輸入上車地點'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _destination,
                  decoration: const InputDecoration(labelText: '目的地'),
                  items: AppConstants.destinations
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setState(() => _destination = value!),
                ),
                if (_destination == AppConstants.customDestination) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customDestinationController,
                    decoration: const InputDecoration(labelText: '自訂目的地'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '請輸入目的地' : null,
                  ),
                ],
                const SizedBox(height: 16),
                Text('服務星期', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: isoWeekdays.map((weekday) {
                    final selected = _serviceWeekdays.contains(weekday);
                    return FilterChip(
                      label: Text(formatServiceWeekdays([weekday])),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _serviceWeekdays.add(weekday);
                          } else {
                            _serviceWeekdays.remove(weekday);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _pickDate(isEndDate: false),
                  child: Text(
                    '開始日期：${DateFormat('yyyy/MM/dd').format(_startDate)}',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _pickDate(isEndDate: true),
                  child: Text(_endDate == null
                      ? '不設定結束日期'
                      : '結束日期：${DateFormat('yyyy/MM/dd').format(_endDate!)}'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _pickTime(isReturn: false),
                  child: Text('接送時間：${_rideTime.format(context)}'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _passengerCount,
                  decoration: const InputDecoration(labelText: '可載人數'),
                  items: List.generate(6, (index) => index + 1)
                      .map((count) => DropdownMenuItem(
                          value: count, child: Text('$count 人')))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _passengerCount = value!),
                ),
                SwitchListTile(
                  value: _needReturn,
                  onChanged: (value) => setState(() => _needReturn = value),
                  title: const Text('提供回程'),
                ),
                if (_needReturn)
                  OutlinedButton(
                    onPressed: () => _pickTime(isReturn: true),
                    child: Text(_returnTime == null
                        ? '選擇回程時間'
                        : '回程時間：${_returnTime!.format(context)}'),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '備註'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.publish),
                  label: Text(_saving ? '送出中...' : '送出審核'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('我的刊登', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          offers.when(
            data: (items) => items.isEmpty
                ? const Text('尚未刊登長期接送方案')
                : Column(
                    children:
                        items.map((offer) => _OfferTile(offer: offer)).toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('讀取失敗：$error'),
          ),
        ],
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer});

  final DriverStandingRideOffer offer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(offer.displayDestination),
        subtitle: Text(
          '${offer.serviceWeekdaysLabel} ${offer.rideTime.substring(0, 5)}',
        ),
        trailing: Chip(label: Text(offer.status.label)),
      ),
    );
  }
}
