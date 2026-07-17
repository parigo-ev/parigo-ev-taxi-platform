import 'dart:async';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_constants.dart';
import 'admin_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';

import 'package:flutter/services.dart';

class AdminDispatchTab extends StatefulWidget {
  const AdminDispatchTab({super.key});

  @override
  State<AdminDispatchTab> createState() => _AdminDispatchTabState();
}

class _AdminDispatchTabState extends State<AdminDispatchTab> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isFirstFetchCompleted = false;
  List<dynamic> _pendingRides = [];
  List<Map<String, String>> _availableDrivers = [];
  Timer? _pollingTimer;
  final Set<String> _knownRideIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _fetchPendingRides(silent: false);
    _fetchAvailableDrivers();
    // Start polling timer
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchPendingRides(silent: true);
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown ||
          event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
        FlutterRingtonePlayer().stop();
        return false;
      }
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pollingTimer?.cancel();
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  Future<void> _fetchAvailableDrivers() async {
    try {
      final response = await ApiClient
          .get(
            Uri.parse('${ApiConstants.baseUrl}/admin/drivers/available'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _availableDrivers = (data['drivers'] as List)
              .map<Map<String, String>>((d) => {
                    'id': (d['id'] ?? 'unknown_id').toString(),
                    'name': (d['name'] ?? 'Unknown').toString(),
                    'lat': (d['lat'] ?? '').toString(),
                    'lng': (d['lng'] ?? '').toString(),
                    'distance': 'Live Location'
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading available drivers: $e');
    }
  }

  Future<void> _fetchPendingRides({bool silent = false}) async {
    if (!silent) {
      if (mounted) setState(() => _isLoading = true);
    }
    try {
      final response = await ApiClient
          .get(
            Uri.parse('${ApiConstants.baseUrl}/admin/rides/pending'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rides = data['rides'] ?? [];
        
        bool hasNewRide = false;
        
        if (mounted) {
          setState(() {
            _pendingRides = rides;
            if (!silent) _isLoading = false;
            
            // Check for new rides to trigger alarm
            for (var ride in rides) {
              final String id = ride['id'].toString();
              if (!_knownRideIds.contains(id)) {
                _knownRideIds.add(id);
                // Only trigger alarm if we already completed the initial fetch
                if (_isFirstFetchCompleted) {
                  hasNewRide = true;
                }
              }
            }
            _isFirstFetchCompleted = true;
          });
          
          if (hasNewRide) {
            FlutterRingtonePlayer().play(
              fromAsset: "assets/sounds/booking_alert.wav",
              looping: true,
              asAlarm: true,
              volume: 1.0,
            );
          }
        }
      } else {
        throw Exception('Failed to load rides');
      }
    } catch (e) {
      print('Error loading pending rides: $e');
      if (!silent && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch pending rides.')),
        );
      }
    }
  }

  Future<void> _cancelRide(String rideId) async {
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
          _fetchPendingRides(silent: false);
        }
      } else {
        throw Exception('Failed to cancel ride');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cancelling ride: $e')));
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _showDriverSelection(String rideId, dynamic pickupData, String date, String time) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryContainer)),
    );

    List<Map<String, dynamic>> fetchedDrivers = [];

    try {
      final response = await ApiClient
          .get(
            Uri.parse('${ApiConstants.baseUrl}/admin/drivers/for-slot?date=$date&time=$time'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        fetchedDrivers = (data['drivers'] as List)
              .map<Map<String, dynamic>>((d) => {
                    'id': (d['id'] ?? 'unknown_id').toString(),
                    'name': (d['name'] ?? 'Unknown').toString(),
                    'lat': (d['lat'] ?? '').toString(),
                    'lng': (d['lng'] ?? '').toString(),
                    'isBooked': d['isBooked'] == true,
                  })
              .toList();
      }
    } catch (e) {
      print('Error fetching drivers for slot: $e');
    }

    if (mounted) Navigator.pop(context); // Close loading dialog

    double? pLat;
    double? pLng;
    if (pickupData is Map) {
      pLat = double.tryParse(pickupData['lat']?.toString() ?? '');
      pLng = double.tryParse(pickupData['lng']?.toString() ?? '');
    }

    // Prepare a list of drivers with their calculated distances
    List<Map<String, dynamic>> sortedDrivers = fetchedDrivers.map((driver) {
      double dist = -1;
      if (pLat != null &&
          pLng != null &&
          driver['lat']!.isNotEmpty &&
          driver['lng']!.isNotEmpty) {
        double dLat = double.tryParse(driver['lat']!) ?? 0;
        double dLng = double.tryParse(driver['lng']!) ?? 0;
        if (dLat != 0 && dLng != 0) {
          dist = _calculateDistance(pLat, pLng, dLat, dLng);
        }
      }
      return {
        ...driver,
        'calculated_dist': dist,
        'display_dist': driver['isBooked'] 
            ? 'Booked for this slot'
            : (dist >= 0 ? '${dist.toStringAsFixed(1)} km away' : 'Location Unknown')
      };
    }).toList();

    // Sort drivers by distance, putting booked drivers at the bottom
    sortedDrivers.sort((a, b) {
      if (a['isBooked'] && !b['isBooked']) return 1;
      if (!a['isBooked'] && b['isBooked']) return -1;
      
      double distA = a['calculated_dist'];
      double distB = b['calculated_dist'];
      if (distA < 0) return 1;
      if (distB < 0) return -1;
      return distA.compareTo(distB);
    });

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Allot Driver',
                    style: GoogleFonts.nunito(
                        fontSize: 20, color: AppTheme.primaryContainer)),
                const SizedBox(height: 16),
                ...sortedDrivers.map((driver) {
                  final isBooked = driver['isBooked'] == true;
                  return ListTile(
                    onTap: isBooked ? null : () {
                      Navigator.pop(context); // Close bottom sheet
                      _allotDriverToRide(
                          rideId, driver['id']!, driver['name']!);
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      child: Icon(Icons.person, color: isBooked ? AppTheme.onSurfaceVariant : AppTheme.primary),
                    ),
                    title: Text(driver['name']!,
                        style: TextStyle(
                            color: isBooked ? AppTheme.onSurfaceVariant : AppTheme.onSurface,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(driver['display_dist']!,
                        style:
                            TextStyle(color: isBooked ? Colors.redAccent : AppTheme.onSurfaceVariant)),
                    trailing: isBooked 
                      ? const Text('BOOKED', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                      : TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close bottom sheet
                            _allotDriverToRide(
                                rideId, driver['id']!, driver['name']!);
                          },
                          child: const Text('ASSIGN',
                              style: TextStyle(
                                  color: AppTheme.primaryFixed,
                                  fontWeight: FontWeight.bold)),
                        ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _allotDriverToRide(
      String rideId, String driverId, String driverName) async {
    // Optimistic UI update
    setState(() {
      _pendingRides.removeWhere((r) => r['id'] == rideId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assigning ride to $driverName...')),
    );

    try {
      final response = await ApiClient
          .post(
            Uri.parse('${ApiConstants.baseUrl}/admin/allot-ride'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'rideId': rideId,
              'driverId': driverId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Successfully assigned ride to $driverName!'),
              backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to allot');
      }
    } catch (e) {
      print('Error allotting ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to assign driver.')),
      );
      // Re-fetch to restore state if it failed
      _fetchPendingRides(silent: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppTheme.onSurface),
          onPressed: () {
            AdminDashboardScreen.of(context)?.openDrawer();
          },
        ),
        title: Text('Admin Dispatch',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: () {
              _fetchPendingRides(silent: false);
              _fetchAvailableDrivers();
            },
          )
        ],
      ),
      body: Listener(
        onPointerDown: (_) => FlutterRingtonePlayer().stop(),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryContainer))
            : _pendingRides.isEmpty
                ? const Center(
                    child: Text(
                      'No pending rides to allot.',
                      style: TextStyle(
                          color: AppTheme.onSurfaceVariant, fontSize: 16),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _fetchPendingRides(silent: false),
                    color: AppTheme.primaryContainer,
                    backgroundColor: AppTheme.surfaceContainer,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _pendingRides.length,
                      itemBuilder: (context, index) {
                        final ride = _pendingRides[index];

                        // Safely extract deeply nested description strings since we use mock data and real firestore data
                        String pDesc = 'Pickup Location';
                        if (ride['pickup'] is Map &&
                            ride['pickup']['description'] != null) {
                          pDesc = ride['pickup']['description'];
                        } else if (ride['pickup'] is String) {
                          pDesc = ride['pickup'];
                        }

                        String dDesc = 'Destination Location';
                        if (ride['destination'] is Map &&
                            ride['destination']['description'] != null) {
                          dDesc = ride['destination']['description'];
                        } else if (ride['destination'] is String) {
                          dDesc = ride['destination'];
                        }

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
                                      Text(
                                        'ID: ${ride['displayId'] ?? ride['id']}',
                                        style: const TextStyle(
                                            color: AppTheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                      Text(
                                        '₹${ride['estimatedFare'] ?? '---'}',
                                        style: const TextStyle(
                                            color: AppTheme.primaryContainer,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: Colors.orangeAccent),
                                        ),
                                        child: const Text(
                                          'PENDING ALLOTMENT',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
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
                                          child: Text(pDesc,
                                              style: const TextStyle(
                                                  color:
                                                      AppTheme.onSurfaceVariant,
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
                                          child: Text(dDesc,
                                              style: const TextStyle(
                                                  color: AppTheme.onSurface,
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month,
                                          color: AppTheme.onSurfaceVariant,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                          ride['scheduledDate']
                                                  ?.split('T')[0] ??
                                              '',
                                          style: const TextStyle(
                                              color: AppTheme.onSurfaceVariant,
                                              fontSize: 12)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.access_time,
                                          color: AppTheme.onSurfaceVariant,
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Text(ride['exactTime'] ?? ride['scheduledTime'] ?? '',
                                          style: const TextStyle(
                                              color: AppTheme.onSurfaceVariant,
                                              fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                      child: PrimaryButton(
                                        text: 'Allot Driver',
                                        onPressed: () => _showDriverSelection(
                                            ride['id'], 
                                            ride['pickup'],
                                            ride['scheduledDate']?.toString().split('T')[0] ?? '',
                                            ride['exactTime']?.toString() ?? ride['scheduledTime']?.toString() ?? ''),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        onPressed: () => _cancelRide(ride['id']),
                                        child: const Text('CANCEL RIDE',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2)),
                                      ),
                                    ),
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
