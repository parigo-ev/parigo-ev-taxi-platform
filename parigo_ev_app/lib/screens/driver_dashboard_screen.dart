import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;
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
import '../widgets/location_disclosure_dialog.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<loc.LocationData>? _locationSubscription;
  final loc.Location _locationService = loc.Location();

  final List<Widget> _tabs = [
    const DriverHomeTab(),
    const DriverMapTab(),
    const DriverEarningsTab(),
    const DriverProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_locationSubscription == null) {
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
        message: 'Parigo EV Driver collects location data to continuously track your position in the background. This allows us to assign you nearby rides and track active trips even when the app is closed or not in use.',
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

    // Permission granted, start background service
    _startBackgroundLocation();
  }

  Future<void> _startBackgroundLocation() async {
    try {
      await _locationService.enableBackgroundMode(enable: true);
      _locationService.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 10000,
        distanceFilter: 10,
      );

      _locationSubscription = _locationService.onLocationChanged.listen((loc.LocationData currentLocation) {
        if (currentLocation.latitude != null && currentLocation.longitude != null) {
          _updateLocationToBackend(currentLocation.latitude!, currentLocation.longitude!);
        }
      });
    } catch (e) {
      debugPrint('Failed to start background location: $e');
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
                    children: List.generate(_tabs.length, (index) {
                      return IgnorePointer(
                        ignoring: _currentIndex != index,
                        child: AnimatedOpacity(
                          opacity: _currentIndex == index ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _tabs[index],
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
