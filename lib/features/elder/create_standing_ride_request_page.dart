import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../models/standing_ride_request.dart';

class CreateStandingRideRequestPage extends ConsumerStatefulWidget {
  const CreateStandingRideRequestPage({super.key});

  @override
  ConsumerState<CreateStandingRideRequestPage> createState() =>
      _CreateStandingRideRequestPageState();
}

class _CreateStandingRideRequestPageState
    extends ConsumerState<CreateStandingRideRequestPage> {
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
  var _recurrencePattern = StandingRideRecurrencePattern.weekdays;
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

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final pickup = _pickupLocation == AppConstants.customPickupLocation
          ? _customPickupController.text.trim()
          : _pickupLocation;
      await ref.read(standingRideServiceProvider).createStandingRideRequest(
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
            recurrencePattern: _recurrencePattern,
            startDate: _startDate,
            endDate: _endDate,
          );
      if (mounted) context.go('/elder/standing');
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
    return Scaffold(
      appBar: AppBar(title: const Text('新增長期接送')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _pickupLocation,
                decoration: const InputDecoration(labelText: '出發地'),
                items: AppConstants.pickupLocations
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => _pickupLocation = value!),
              ),
              if (_pickupLocation == AppConstants.customPickupLocation) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customPickupController,
                  decoration: const InputDecoration(labelText: '自行輸入出發地'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '請輸入出發地' : null,
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
                  decoration: const InputDecoration(labelText: '自行輸入目的地'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '請輸入目的地' : null,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<StandingRideRecurrencePattern>(
                initialValue: _recurrencePattern,
                decoration: const InputDecoration(labelText: '週期'),
                items: StandingRideRecurrencePattern.values
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _recurrencePattern = value!),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _pickDate(isEndDate: false),
                child:
                    Text('起始日期：${DateFormat('yyyy/MM/dd').format(_startDate)}'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isEndDate: true),
                      child: Text(_endDate == null
                          ? '選擇結束日'
                          : '結束日：${DateFormat('yyyy/MM/dd').format(_endDate!)}'),
                    ),
                  ),
                  if (_endDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _endDate = null),
                      icon: const Icon(Icons.clear),
                      tooltip: '清除結束日',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _pickTime(isReturn: false),
                child: Text('出發時間：${_rideTime.format(context)}'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _passengerCount,
                decoration: const InputDecoration(labelText: '人數'),
                items: List.generate(6, (index) => index + 1)
                    .map((count) =>
                        DropdownMenuItem(value: count, child: Text('$count 人')))
                    .toList(),
                onChanged: (value) => setState(() => _passengerCount = value!),
              ),
              SwitchListTile(
                value: _needReturn,
                onChanged: (value) => setState(() => _needReturn = value),
                title: const Text('需要回程'),
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
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? '送出中...' : '送出審核'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
