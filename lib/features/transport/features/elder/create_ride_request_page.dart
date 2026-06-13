import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';

class CreateRideRequestPage extends ConsumerStatefulWidget {
  const CreateRideRequestPage({super.key});

  @override
  ConsumerState<CreateRideRequestPage> createState() =>
      _CreateRideRequestPageState();
}

class _CreateRideRequestPageState extends ConsumerState<CreateRideRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _customPickupController = TextEditingController();
  final _customDestinationController = TextEditingController();
  final _noteController = TextEditingController();
  var _pickupLocation = AppConstants.pickupLocations.first;
  var _destination = AppConstants.destinations.first;
  var _rideDate = DateTime.now().add(const Duration(days: 1));
  var _rideTime = const TimeOfDay(hour: 9, minute: 0);
  var _needReturn = false;
  TimeOfDay? _returnTime;
  var _passengerCount = 1;
  var _saving = false;

  @override
  void dispose() {
    _customPickupController.dispose();
    _customDestinationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _rideDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null) setState(() => _rideDate = result);
  }

  Future<void> _pickTime({required bool isReturn}) async {
    final result = await showTimePicker(
      context: context,
      initialTime: isReturn ? (_returnTime ?? _rideTime) : _rideTime,
    );
    if (result != null) {
      setState(() {
        if (isReturn) {
          _returnTime = result;
        } else {
          _rideTime = result;
        }
      });
    }
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
      final customDestination = _destination == AppConstants.customDestination
          ? _customDestinationController.text.trim()
          : null;

      final rideRequestId = await ref
          .read(rideServiceProvider)
          .createRideRequest(
            pickupLocation: pickup,
            destination: _destination,
            customDestination: customDestination,
            rideDate: _rideDate,
            rideTime: _formatTime(_rideTime),
            passengerCount: _passengerCount,
            needReturn: _needReturn,
            returnTime: _needReturn && _returnTime != null
                ? _formatTime(_returnTime!)
                : null,
            note: _noteController.text,
          );

      try {
        await ref
            .read(greedyMatchingServiceProvider)
            .matchDriver(rideRequestId);
      } catch (error, stackTrace) {
        debugPrint('Greedy Matching failed after ride request insert: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('搭乘需求已送出')));
      context.go('/transport/elder');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送出搭乘需求失敗：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增搭乘需求')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _pickupLocation,
                  decoration: const InputDecoration(labelText: '上車地點'),
                  items: AppConstants.pickupLocations
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
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
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
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
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(
                    '搭車日期：${DateFormat('yyyy/MM/dd').format(_rideDate)}',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _pickTime(isReturn: false),
                  child: Text('搭車時間：${_rideTime.format(context)}'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _passengerCount,
                  decoration: const InputDecoration(labelText: '人數'),
                  items: List.generate(6, (index) => index + 1)
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count 人'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _passengerCount = value!),
                ),
                SwitchListTile(
                  value: _needReturn,
                  onChanged: (value) => setState(() => _needReturn = value),
                  title: const Text('需要回程'),
                ),
                if (_needReturn)
                  OutlinedButton(
                    onPressed: () => _pickTime(isReturn: true),
                    child: Text(
                      _returnTime == null
                          ? '選擇回程時間'
                          : '回程時間：${_returnTime!.format(context)}',
                    ),
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
                  child: Text(_saving ? '送出中...' : '送出需求'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
