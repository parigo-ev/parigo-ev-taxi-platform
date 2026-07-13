import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../core/api_keys.dart';
import 'destination_search_screen.dart';
import 'schedule_ride_screen.dart';
import 'scheduled_rides_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import '../widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/parigo_logo.dart';
import '../widgets/location_disclosure_dialog.dart';
import 'package:parigo_ev_app/core/api_client.dart';
import '../core/deep_link_handler.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({Key? key}) : super(key: key);

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _mapController;
  final LatLng _initialPosition =
      const LatLng(22.7196, 75.8577); // Default to Indore
  Position? _currentPosition;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  bool _isSelectingPickupOnMap = false;
  bool _isSelectingDestinationOnMap = false;
  LatLng? _customPickupPosition;
  String? _customPickupAddress;
  LatLng? _customDestinationPosition;
  String? _customDestinationAddress;
  LatLng _cameraPosition = const LatLng(22.7196, 75.8577);
  String _name = 'Customer';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
    });
    _phone = UserSession().phone;
    _fetchProfile();
    _loadLiveDrivers();
    _timer =
        Timer.periodic(const Duration(seconds: 10), (_) => _loadLiveDrivers());
        
    DeepLinkHandler().pendingDestination.addListener(_handleDeepLink);
    _handleDeepLink(); // check initial state
  }

  void _handleDeepLink() {
    final dest = DeepLinkHandler().pendingDestination.value;
    if (dest != null) {
      if (mounted) {
        setState(() {
          _customDestinationPosition = LatLng(dest['lat'], dest['lng']);
          _customDestinationAddress = dest['description'];
        });
        
        _fetchRouteAndDraw(dest);
        
        if (dest['description'] == 'Shared Location') {
           _fetchAddressFromCoordinates(_customDestinationPosition!).then((address) {
             if (mounted) {
               setState(() {
                  _customDestinationAddress = address;
               });
             }
           });
        }
      }
      DeepLinkHandler().clearPendingDestination();
    }
  }

  Timer? _timer;

  Future<void> _fetchProfile() async {
    if (_phone.isEmpty) return;
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/user/profile/$_phone'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _name = data['name'] ?? 'Customer';
          });
        }
      }
    } catch (e) {
      print('Failed to load profile: $e');
    }
  }

  @override
  void dispose() {
    DeepLinkHandler().pendingDestination.removeListener(_handleDeepLink);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_currentPosition == null) {
        _checkLocationPermission();
      }
    }
  }

  void _updatePickupMarker() {
    final double pLat = _customPickupPosition?.latitude ??
        _currentPosition?.latitude ??
        _initialPosition.latitude;
    final double pLng = _customPickupPosition?.longitude ??
        _currentPosition?.longitude ??
        _initialPosition.longitude;

    setState(() {
      _markers = Set.from(_markers.where((m) => m.markerId.value != 'pickup'))
        ..add(Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pLat, pLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ));
    });
  }

  Future<void> _loadLiveDrivers() async {
    try {
      final response = await ApiClient.get(
            Uri.parse('${ApiConstants.baseUrl}/admin/drivers/available'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> drivers = data['drivers'] ?? [];

        Set<Marker> newMarkers = Set.from(_markers.where((m) =>
            m.markerId.value == 'dest' || m.markerId.value == 'pickup')); // Keep destination and pickup markers if they exist

        for (var d in drivers) {
          if (d['lat'] == null || d['lng'] == null) continue;

          newMarkers.add(Marker(
            markerId: MarkerId('driver_${d['id']}'),
            position: LatLng(double.parse(d['lat'].toString()),
                double.parse(d['lng'].toString())),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow),
            infoWindow:
                InfoWindow(title: 'Parigo EV', snippet: 'Available nearby'),
          ));
        }

        if (mounted) {
          setState(() {
            _markers = newMarkers;
          });
        }
      }
    } catch (e) {
      print('Error fetching live driver locations: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print("DEBUG: Location service enabled? $serviceEnabled");
    if (!serviceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('GPS is Disabled'),
            content: const Text('Please turn on your phone\'s GPS/Location Services so we can automatically set your pickup location and show nearby EV drivers.'),
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
    print("DEBUG: Current location permission state: $permission");
    
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      // 1. Show Prominent Disclosure for Google Play / App Store compliance
      final accepted = await LocationDisclosureDialog.show(
        context,
        message: 'Parigo EV collects location data to accurately locate your pickup point and show nearby drivers, even if you temporarily minimize the app.',
      );
      
      if (accepted != true) {
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        // Guide user to settings
        print("DEBUG: Permission is denied forever. Suggesting settings.");
        Geolocator.openAppSettings();
        return;
      }

      // 2. Request actual system permission
      permission = await Geolocator.requestPermission();
      print("DEBUG: Requested system permission, result: $permission");
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Geolocator.openAppSettings();
      return;
    }

    // Permission granted, get current location
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _customPickupAddress = 'Fetching address...';
      _updatePickupMarker();
    });

    if (_customDestinationPosition != null) {
      _fetchRouteAndDraw({
        'lat': _customDestinationPosition!.latitude,
        'lng': _customDestinationPosition!.longitude,
        'description': _customDestinationAddress ?? 'Destination',
      });
    } else {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 15));
    }

    final address = await _fetchAddressFromCoordinates(
        LatLng(position.latitude, position.longitude));
    if (mounted) {
      setState(() {
        _customPickupAddress = address;
      });
    }
  }

  Future<String> _fetchAddressFromCoordinates(LatLng pos) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=${ApiKeys.googleMapsKey}';
      final response = await ApiClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}';
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _fetchRouteAndDraw(Map<String, dynamic> destination) async {
    final double pLat = _customPickupPosition?.latitude ??
        _currentPosition?.latitude ??
        22.7196;
    final double pLng = _customPickupPosition?.longitude ??
        _currentPosition?.longitude ??
        75.8577;
    final String pDesc = _customPickupAddress ?? 'Current Location';

    final double dLat = destination['lat'] as double;
    final double dLng = destination['lng'] as double;
    final String dDesc = destination['description'] ?? 'Destination';

    // Use Google Maps Directions API for routing
    try {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$pLat,$pLng&destination=$dLat,$dLng&key=${ApiKeys.googleMapsKey}';
      final response = await ApiClient.get(Uri.parse(url));

      List<LatLng> routePoints = [];

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final pointsString = data['routes'][0]['overview_polyline']['points'];
          routePoints = _decodePolyline(pointsString);
        }
      }

      // Fallback to straight line if API fails
      if (routePoints.isEmpty) {
        routePoints = [LatLng(pLat, pLng), LatLng(dLat, dLng)];
      }

      setState(() {
        final newMarker = Marker(
          markerId: const MarkerId('dest'),
          position: LatLng(dLat, dLng),
        );
        final pickupMarker = Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pLat, pLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        );
        final newPolyline = Polyline(
          polylineId: const PolylineId('route'),
          color: AppTheme.primaryContainer,
          width: 5,
          points: routePoints,
        );

        _markers = Set.from(_markers.where((m) => m.markerId.value != 'dest' && m.markerId.value != 'pickup'))
          ..add(newMarker)
          ..add(pickupMarker);
        _polylines = Set.from(_polylines)..add(newPolyline);
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              pLat < dLat ? pLat : dLat,
              pLng < dLng ? pLng : dLng,
            ),
            northeast: LatLng(
              pLat > dLat ? pLat : dLat,
              pLng > dLng ? pLng : dLng,
            ),
          ),
          100));
    } catch (e) {
      print('Routing error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not calculate route: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: AppTheme.surfaceContainer.withOpacity(0.4),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryContainer.withOpacity(0.3),
                          AppTheme.secondaryContainer.withOpacity(0.3)
                        ],
                      ),
                      border: Border(bottom: BorderSide(color: AppTheme.onSurface.withOpacity(0.1), width: 1.5)),
                    ),
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    child:
                        Icon(Icons.person, size: 40, color: AppTheme.onSurface),
                  ),
                  const Spacer(),
                  Text(_name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.bold)),
                  Text(_phone.isEmpty ? 'Loading...' : _phone,
                      style: const TextStyle(color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: AppTheme.onSurfaceVariant),
              title: const Text('Home',
                  style: TextStyle(color: AppTheme.onSurface)),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today,
                  color: AppTheme.onSurfaceVariant),
              title: const Text('Scheduled Rides',
                  style: TextStyle(color: AppTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ScheduledRidesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet,
                  color: AppTheme.onSurfaceVariant),
              title: const Text('Wallet',
                  style: TextStyle(color: AppTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WalletScreen()));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.person, color: AppTheme.onSurfaceVariant),
              title: const Text('Profile',
                  style: TextStyle(color: AppTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileScreen()));
              },
            ),
                ],
              ),
            ),
          ),
        ),
      ),
      // FAB removed, SOS moved to top navigation row
      body: Stack(
        children: [
          // 1. Map Layer
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              polylines: _polylines,
              markers: _markers,
              mapType: MapType
                  .normal, // Note: You can apply a dark style JSON here to match "Solar Flare" perfectly
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onCameraMove: (position) {
                _cameraPosition = position.target;
              },
            ),
          ),

          // 2. Map Center Pin
          if (_isSelectingPickupOnMap || _isSelectingDestinationOnMap)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_on,
                    size: 50,
                    color: _isSelectingPickupOnMap ? Colors.green : Colors.red),
              ),
            ),

          // Gradient overlay for bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.background.withOpacity(0.6),
                      AppTheme.background,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Confirm Pickup Location
          if (_isSelectingPickupOnMap)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999))),
                onPressed: () async {
                  setState(() {
                    _customPickupPosition = _cameraPosition;
                    _isSelectingPickupOnMap = false;
                    _customPickupAddress = 'Fetching address...';
                    _updatePickupMarker();
                  });
                  final address =
                      await _fetchAddressFromCoordinates(_cameraPosition);
                  if (mounted) {
                    setState(() {
                      _customPickupAddress = address;
                    });
                  }
                },
                child: const Text('Confirm Pickup Location',
                    style: TextStyle(
                        color: AppTheme.onPrimaryContainer,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),

          if (_isSelectingDestinationOnMap)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999))),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Processing Destination...'),
                      duration: Duration(seconds: 1)));

                  final currentCam = _cameraPosition;
                  setState(() {
                    _customDestinationPosition = currentCam;
                    _isSelectingDestinationOnMap = false;
                    _customDestinationAddress = 'Fetching address...';
                  });
                  final address =
                      await _fetchAddressFromCoordinates(currentCam);
                  if (mounted) {
                    setState(() {
                      _customDestinationAddress = address;
                    });
                    _fetchRouteAndDraw({
                      'description': address,
                      'lat': currentCam.latitude,
                      'lng': currentCam.longitude,
                    });
                  }
                },
                child: const Text('Confirm Destination Location',
                    style: TextStyle(
                        color: AppTheme.onPrimaryContainer,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),

          // 2. Top Navigation (Back, Logo, SOS)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Menu Button
                _buildGlassButton(
                  icon: Icons.menu,
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                
                // Logo (Pill shaped)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.onSurface.withOpacity(0.2), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 24,
                          )
                        ],
                      ),
                      child: ParigoLogo(
                        textStyle:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                  ),
                ),

                // SOS Button
                _buildGlassButton(
                  icon: Icons.sos,
                  iconColor: Colors.redAccent,
                  onPressed: () async {
                    final Uri url = Uri.parse('whatsapp://send?phone=+918878587615');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not launch WhatsApp')));
                    }
                  },
                ),
              ],
            ),
          ),

          // 4. Where to? Card
          if (!_isSelectingPickupOnMap && !_isSelectingDestinationOnMap)
            Positioned(
              bottom: 132, // Exactly 20px gap above the nav bar (112 + 20)
              left: 20,
              right: 20,
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.outline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),

                    Text('Where to?',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Inputs
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.onSurface.withOpacity(0.1)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.surfaceContainer,
                            ),
                            child: const Icon(Icons.trip_origin,
                                color: AppTheme.primaryContainer, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          DestinationSearchScreen(
                                            title: 'Search Pickup',
                                            hintText: 'Enter pickup location',
                                            currentLat: _currentPosition?.latitude,
                                            currentLng: _currentPosition?.longitude,
                                          )),
                                );
                                if (result != null) {
                                  setState(() {
                                    _customPickupAddress =
                                        result['description'];
                                    _customPickupPosition =
                                        LatLng(result['lat'], result['lng']);
                                    _isSelectingPickupOnMap = false;
                                    _updatePickupMarker();
                                  });
                                  _mapController?.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                          _customPickupPosition!, 15));
                                }
                              },
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: _customPickupAddress ?? 'Current location',
                                hintStyle: TextStyle(
                                    color: AppTheme.onSurfaceVariant
                                        .withOpacity(0.7),
                                    fontSize: 14),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.my_location,
                                color: AppTheme.primary, size: 20),
                            onPressed: () async {
                              if (_currentPosition != null) {
                                setState(() {
                                  _customPickupPosition = null;
                                  _customPickupAddress = 'Fetching address...';
                                  _updatePickupMarker();
                                });
                                _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                        LatLng(_currentPosition!.latitude,
                                            _currentPosition!.longitude),
                                        15));
                                final address = await _fetchAddressFromCoordinates(
                                    LatLng(_currentPosition!.latitude,
                                        _currentPosition!.longitude));
                                if (mounted) {
                                  setState(() {
                                    _customPickupAddress = address;
                                  });
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.map,
                                color: AppTheme.primary, size: 20),
                            onPressed: () {
                              setState(() {
                                _isSelectingPickupOnMap = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                          color: AppTheme.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppTheme.onSurface.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppTheme.primaryContainer.withOpacity(0.1),
                                blurRadius: 15)
                          ]),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryContainer,
                                boxShadow: [
                                  BoxShadow(
                                      color: AppTheme.primaryContainer
                                          .withOpacity(0.5),
                                      blurRadius: 10)
                                ]),
                            child: const Icon(Icons.location_on,
                                color: AppTheme.onPrimaryContainer, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          DestinationSearchScreen(
                                            currentLat: _currentPosition?.latitude,
                                            currentLng: _currentPosition?.longitude,
                                          )),
                                );
                                if (result != null) {
                                  setState(() {
                                    _customDestinationAddress =
                                        result['description'];
                                    _customDestinationPosition =
                                        LatLng(result['lat'], result['lng']);
                                  });
                                  _fetchRouteAndDraw(result);
                                }
                              },
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: _customDestinationAddress ??
                                    'Search destination',
                                hintStyle: const TextStyle(fontSize: 14),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.map,
                                color: AppTheme.primary, size: 20),
                            onPressed: () {
                              setState(() {
                                _isSelectingDestinationOnMap = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      height: 48,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryContainer,
                              AppTheme.primary
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppTheme.primaryContainer.withOpacity(0.4),
                                blurRadius: 20)
                          ]),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            if (_customDestinationPosition == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please select a destination first')));
                              return;
                            }
                            final pickup = {
                              'lat': _customPickupPosition?.latitude ??
                                  _currentPosition?.latitude ??
                                  22.7196,
                              'lng': _customPickupPosition?.longitude ??
                                  _currentPosition?.longitude ??
                                  75.8577,
                              'description':
                                  _customPickupAddress ?? 'Current Location',
                            };
                            final dest = {
                              'lat': _customDestinationPosition!.latitude,
                              'lng': _customDestinationPosition!.longitude,
                              'description':
                                  _customDestinationAddress ?? 'Destination',
                            };

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScheduleRideScreen(
                                    pickup: pickup, destination: dest),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_month,
                                  color: AppTheme.onPrimaryContainer),
                              SizedBox(width: 8),
                              Text('Schedule Ride',
                                  style: TextStyle(
                                      color: AppTheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    Color? iconColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.onSurface.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24)
              ],
            ),
            child: Icon(icon, color: iconColor ?? AppTheme.onSurface, size: 28),
          ),
        ),
      ),
    );
  }
}
