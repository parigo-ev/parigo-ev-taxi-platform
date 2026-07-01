import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/ride_chat_bottom_sheet.dart';
import '../widgets/payment_selection_sheet.dart';
import 'feedback_screen.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_constants.dart';
import 'customer_active_ride_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _isLoading = true;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchRides();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchRides(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRides({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await ApiClient
          .get(
            Uri.parse('${ApiConstants.baseUrl}/ride/customer?uid=${user.uid}'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> fetched = data['rides'] ?? [];

        setState(() {
          _rides = fetched
              .where((r) => r['status'] != 'COMPLETED' && r['status'] != 'CANCELLED')
              .map<Map<String, dynamic>>((r) {
            String pickup = 'Unknown Pickup';
            if (r['pickup'] is Map) {
              pickup = r['pickup']['description'] ?? r['pickup']['address'] ?? 'Unknown Pickup';
            } else if (r['pickup'] is String) {
              try {
                final map = jsonDecode(r['pickup']);
                pickup = map['description'] ?? map['address'] ?? r['pickup'];
              } catch (_) {
                pickup = r['pickup'];
              }
            }

            String dest = 'Unknown Destination';
            if (r['destination'] is Map) {
              dest = r['destination']['description'] ?? r['destination']['address'] ?? 'Unknown Destination';
            } else if (r['destination'] is String) {
              try {
                final map = jsonDecode(r['destination']);
                dest = map['description'] ?? map['address'] ?? r['destination'];
              } catch (_) {
                dest = r['destination'];
              }
            }

            final String date = r['scheduledDate']?.toString() ?? 'Now';
            final String time = r['exactTime']?.toString() ?? r['scheduledTime']?.toString() ?? '';

            return {
              'id': r['id']?.toString() ?? '',
              'date': date,
              'time': time,
              'pickup': pickup,
              'destination': dest,
              'status': r['status'] == 'ALLOTTED'
                  ? 'CONFIRMED'
                  : (r['status'] == 'SCHEDULED'
                      ? 'PENDING'
                      : r['status']?.toString() ?? 'PENDING'),
              'otp': r['otp']?.toString() ?? '---',
              'driver_name': r['driverDetails'] != null ? r['driverDetails']['name'] : (r['assignedDriverId'] != null || r['driverId'] != null ? 'Driver Assigned' : null),
              'vehicle': r['driverDetails'] != null ? r['driverDetails']['vehicle_type'] : (r['assignedDriverId'] != null || r['driverId'] != null ? 'EV' : null),
              'profile_picture_url': r['driverDetails'] != null ? r['driverDetails']['profile_picture_url'] : null,
              'driver_phone': r['driverDetails'] != null ? r['driverDetails']['phone'] : null,
              'assignedDriverId': r['assignedDriverId']?.toString() ?? r['driverId']?.toString(),
              'raw_pickup': r['pickup'],
              'raw_destination': r['destination'],
            };
          }).toList();
          
          if (!silent) _isLoading = false;
        });

        _checkPendingPayments();
      } else {
        throw Exception('Failed to load rides');
      }
    } catch (e) {
      print('Error fetching rides: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _isPaymentSheetOpen = false;

  void _checkPendingPayments() {
    if (_isPaymentSheetOpen) return;
    
    for (var ride in _rides) {
      if (ride['status'] == 'PENDING_PAYMENT') {
        _isPaymentSheetOpen = true;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (context) => PaymentSelectionBottomSheet(rideData: ride),
        ).then((_) {
          _isPaymentSheetOpen = false;
        });
        break; // Only show for the first one
      }
    }
  }

  Future<void> _cancelRide(String rideId) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/driver/rides/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rideId': rideId,
          'status': 'CANCELLED'
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride Cancelled Successfully')));
          _fetchRides();
        }
      } else {
        throw Exception('Failed to cancel ride');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cancelling ride: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Scheduled Rides',
            style: GoogleFonts.nunito(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _fetchRides,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryContainer))
              : _rides.isEmpty
                  ? const Center(
                      child: Text(
                        'No upcoming scheduled rides.',
                        style: TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRides,
                      color: AppTheme.primaryContainer,
                      backgroundColor: AppTheme.surfaceContainer,
                      child: ListView.builder(
                        itemCount: _rides.length,
                        itemBuilder: (context, index) {
                          final ride = _rides[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ride['date'] ?? '',
                                                  style: const TextStyle(
                                                      color: AppTheme.primaryContainer,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if ((ride['time'] ?? '').isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    ride['time'] ?? '',
                                                    style: const TextStyle(
                                                        color: AppTheme.primary,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ]
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: ride['status'] == 'CONFIRMED'
                                                ? Colors.green.withOpacity(0.2)
                                                : AppTheme
                                                    .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color:
                                                  ride['status'] == 'CONFIRMED'
                                                      ? Colors.greenAccent
                                                      : AppTheme.outline,
                                            ),
                                          ),
                                          child: Text(
                                            ride['status'] ?? '',
                                            style: TextStyle(
                                              color: ride['status'] ==
                                                      'CONFIRMED'
                                                  ? Colors.greenAccent
                                                  : AppTheme.onSurfaceVariant,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        const Icon(Icons.my_location,
                                            color: AppTheme.primary, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(ride['pickup'] ?? '',
                                                style: const TextStyle(
                                                    color: AppTheme
                                                        .onSurfaceVariant,
                                                    fontSize: 14))),
                                      ],
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 9),
                                      child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: SizedBox(
                                              height: 12,
                                              child: VerticalDivider(
                                                  color: AppTheme.outline))),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            color: AppTheme.primaryContainer,
                                            size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(
                                                ride['destination'] ?? '',
                                                style: const TextStyle(
                                                    color: AppTheme.onSurface,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ],
                                    ),
                                    if (ride['status'] == 'CONFIRMED' || ride['status'] == 'ARRIVED') ...[
                                      const SizedBox(height: 24),
                                      const Divider(
                                          color:
                                              AppTheme.surfaceContainerHighest),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          ride['profile_picture_url'] != null
                                              ? CircleAvatar(
                                                  radius: 24,
                                                  backgroundImage: NetworkImage(
                                                      ride[
                                                          'profile_picture_url']))
                                              : const CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: AppTheme
                                                      .surfaceContainerHighest,
                                                  child: Icon(Icons.person,
                                                      color: AppTheme
                                                          .onSurfaceVariant)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    ride['driver_name'] ??
                                                        'Driver Assigned',
                                                    style: const TextStyle(
                                                        color:
                                                            AppTheme.onSurface,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16)),
                                                const SizedBox(height: 4),
                                                Text(
                                                    ride['vehicle'] ??
                                                        'Vehicle Details',
                                                    style: const TextStyle(
                                                        color: AppTheme
                                                            .onSurfaceVariant,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                builder: (context) => RideChatBottomSheet(
                                                  rideId: ride['id'] ?? '',
                                                  role: 'Customer',
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      AppTheme.primaryContainer),
                                              child: const Icon(Icons.chat,
                                                  color:
                                                      AppTheme.onPrimaryContainer,
                                                  size: 20),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () async {
                                              final phone = ride['driver_phone'];
                                              if (phone != null && phone.isNotEmpty) {
                                                final Uri launchUri = Uri(
                                                  scheme: 'tel',
                                                  path: phone,
                                                );
                                                if (await canLaunchUrl(launchUri)) {
                                                  await launchUrl(launchUri);
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer')));
                                                }
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available')));
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      AppTheme.primaryContainer),
                                              child: const Icon(Icons.call,
                                                  color:
                                                      AppTheme.onPrimaryContainer,
                                                  size: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(
                                          color:
                                              AppTheme.surfaceContainerHighest),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Ride OTP',
                                              style: TextStyle(
                                                  color:
                                                      AppTheme.onSurfaceVariant,
                                                  fontSize: 14)),
                                          Text(ride['otp'] ?? '',
                                              style: const TextStyle(
                                                  color: AppTheme.onSurface,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 4)),
                                        ],
                                      ),
                                      ],
                                      if (ride['status'] == 'CONFIRMED' || ride['status'] == 'ARRIVED' || ride['status'] == 'IN_PROGRESS') ...[
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.location_on, color: Colors.white),
                                            label: const Text('TRACK RIDE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () {
                                               Navigator.push(
                                                 context,
                                                 MaterialPageRoute(builder: (context) => CustomerActiveRideScreen(rideData: ride))
                                               );
                                            },
                                          ),
                                        )
                                      ],
                                    if (ride['status'] == 'CONFIRMED' ||
                                        ride['status'] == 'PENDING') ...[
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            side: const BorderSide(
                                                color: Colors.redAccent),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                          ),
                                          onPressed: () {
                                            _cancelRide(ride['id']!);
                                          },
                                          child: const Text('CANCEL RIDE',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2)),
                                        ),
                                      ),
                                      if (ride['status'] == 'CONFIRMED') ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        FeedbackScreen(
                                                          role: 'Customer',
                                                          rideId: ride['id'] ??
                                                              'mock_ride_123',
                                                          otherPartyName: ride[
                                                                  'driver_name'] ??
                                                              'Driver',
                                                        )),
                                              );
                                            },
                                            child: const Text(
                                                'MOCK COMPLETE RIDE (TEST FEEDBACK)',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                      ]
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
