import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/driver_standing_ride_offer.dart';
import '../models/standing_ride_request.dart';

class StandingRideService {
  StandingRideService({SupabaseClient? client})
      : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<void> createDriverStandingRideOffer({
    required String pickupLocation,
    required String destination,
    required String? customDestination,
    required String rideTime,
    required int passengerCount,
    required bool needReturn,
    required String? returnTime,
    required String note,
    required List<int> serviceWeekdays,
    required DateTime startDate,
    required DateTime? endDate,
  }) async {
    await _client.rpc('create_driver_standing_ride_offer', params: {
      'p_pickup_location': pickupLocation,
      'p_destination': destination,
      'p_custom_destination': customDestination,
      'p_ride_time': rideTime,
      'p_passenger_count': passengerCount,
      'p_need_return': needReturn,
      'p_return_time': returnTime,
      'p_note': note,
      'p_service_weekdays': serviceWeekdays,
      'p_start_date': startDate.toIso8601String().split('T').first,
      'p_end_date': endDate?.toIso8601String().split('T').first,
    });
  }

  Stream<List<StandingRideRequest>> watchMyStandingRideRequests() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return _client
        .from('standing_ride_requests')
        .stream(primaryKey: ['id'])
        .eq('elder_id', user.id)
        .order('created_at', ascending: false)
        .map(_parseRows);
  }

  Stream<List<DriverStandingRideOffer>> watchMyDriverStandingRideOffers() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return _client
        .from('driver_standing_ride_offers')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(_parseOfferRows);
  }

  Stream<List<DriverStandingRideOffer>>
      watchApprovedDriverStandingRideOffers() {
    return _client
        .from('driver_standing_ride_offers')
        .stream(primaryKey: ['id'])
        .eq('status', DriverStandingRideOfferStatus.approved.databaseValue)
        .order('start_date')
        .map(_parseOfferRows);
  }

  Stream<List<DriverStandingRideOffer>> watchAdminDriverStandingRideOffers({
    DriverStandingRideOfferStatus? status,
  }) {
    if (status != null) {
      return _client
          .from('driver_standing_ride_offers')
          .stream(primaryKey: ['id'])
          .eq('status', status.databaseValue)
          .order('created_at', ascending: false)
          .map(_parseOfferRows);
    }
    return _client
        .from('driver_standing_ride_offers')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(_parseOfferRows);
  }

  Stream<List<DriverStandingRideOffer>> watchPendingDriverStandingRideOffers() {
    return watchAdminDriverStandingRideOffers(
      status: DriverStandingRideOfferStatus.pending,
    );
  }

  Future<void> approveDriverStandingRideOffer(String id) async {
    await _client.rpc('approve_driver_standing_ride_offer', params: {
      'p_offer_id': id,
    });
  }

  Future<void> rejectDriverStandingRideOffer(String id, String? reason) async {
    await _client.rpc('reject_driver_standing_ride_offer', params: {
      'p_offer_id': id,
      'p_reason': reason,
    });
  }

  Future<void> cancelDriverStandingRideOffer(String id) async {
    await _client.rpc('cancel_driver_standing_ride_offer', params: {
      'p_offer_id': id,
    });
  }

  Future<void> selectDriverStandingRideOffer(String id) async {
    await _client.rpc('select_driver_standing_ride_offer', params: {
      'p_offer_id': id,
    });
  }

  List<StandingRideRequest> _parseRows(List<Map<String, dynamic>> rows) {
    return rows
        .map((row) =>
            StandingRideRequest.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  List<DriverStandingRideOffer> _parseOfferRows(
      List<Map<String, dynamic>> rows) {
    return rows
        .map((row) =>
            DriverStandingRideOffer.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
