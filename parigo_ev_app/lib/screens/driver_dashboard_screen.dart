import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'driver_home_tab.dart';
import 'driver_map_tab.dart';
import 'driver_earnings_tab.dart';
import 'driver_profile_tab.dart';
import '../widgets/glass_card.dart';
import '../widgets/parigo_logo.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import '../widgets/location_disclosure_dialog.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isOnline = false;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchInitialOnlineStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialOnlineStatus() async {
    final phone = UserSession().phone;
    if (phone == null || phone.isEmpty) return;

    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/driver/profile/$phone'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool initialOnline = data['is_online'] ?? false;
        setState(() {
          _isOnline = initialOnline;
        });
        if (initialOnline) {
          _checkLocationPermission();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch initial online status: $e');
    }
  }

  Future<void> _toggleOnline(bool val) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isOnline = val;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/driver/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': user.uid,
          'isOnline': val,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update status on backend');
      }
    } catch (e) {
      debugPrint('Failed to toggle status: $e');
      // Revert status on failure
      setState(() {
        _isOnline = !val;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
      return;
    }

    if (val) {
      _checkLocationPermission();
    } else {
      _locationSubscription?.cancel();
      _locationSubscription = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isOnline && _locationSubscription == null) {
        _checkLocationPermission();
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('GPS is Disabled'),
            content: const Text('Please turn on your phone\'s GPS/Location Services so we can track your location for assignments.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openLocationSettings();
                },
                child: const Text('Turn On'),
              ),
            ],
          ),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      final accepted = await LocationDisclosureDialog.show(
        context,
        message: 'Parigo EV Driver collects location data to continuously track your position. This allows us to assign you nearby rides and track active trips.',
      );
      
      if (accepted != true) return;

      if (permission == LocationPermission.deniedForever) {
        Geolocator.openAppSettings();
        return;
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      Geolocator.openAppSettings();
      return;
    }

    _startBackgroundLocation();
  }

  Future<void> _startBackgroundLocation() async {
    try {
      _locationSubscription?.cancel();
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (_isOnline) {
          _updateLocationToBackend(position.latitude, position.longitude);
        }
      });
    } catch (e) {
      debugPrint('Failed to start location stream: $e');
    }
  }

  Future<void> _updateLocationToBackend(double lat, double lng) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/driver/update-location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': user.uid,
          'lat': lat,
          'lng': lng,
        }),
      );
    } catch (e) {
      debugPrint('Failed to update location to backend: $e');
    }
  }

  List<Widget> _getTabs() {
    return [
      DriverHomeTab(
        isOnline: _isOnline,
        onToggleOnline: _toggleOnline,
      ),
      const DriverMapTab(),
      const DriverEarningsTab(),
      const DriverProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient Background Flare
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.5,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryContainer.withOpacity(0.15),
                    AppTheme.secondaryContainer.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.8],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Top AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Center(
                    child: ParigoLogo(
                      textStyle: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),

                // Main Tab Content
                Expanded(
                  child: Stack(
                    children: List.generate(_getTabs().length, (index) {
                      return IgnorePointer(
                        ignoring: _currentIndex != index,
                        child: AnimatedOpacity(
                          opacity: _currentIndex == index ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _getTabs()[index],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Nav
          Positioned(
            bottom: 56,
            left: 24,
            right: 24,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(0, Icons.home),
                  _buildNavItem(1, Icons.map),
                  _buildNavItem(2, Icons.account_balance_wallet),
                  _buildNavItem(3, Icons.person),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: isSelected
            ? BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primaryContainer, AppTheme.primary]),
                shape: BoxShape.circle,
                boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryContainer.withOpacity(0.5),
                        blurRadius: 20)
                  ])
            : null,
        child: Icon(
          icon,
          color: isSelected
              ? AppTheme.onPrimaryContainer
              : AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
