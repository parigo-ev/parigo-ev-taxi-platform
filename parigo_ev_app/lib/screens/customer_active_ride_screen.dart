import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import '../core/api_keys.dart';
import '../widgets/glass_card.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class CustomerActiveRideScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;

  const CustomerActiveRideScreen({super.key, required this.rideData});

  @override
  State<CustomerActiveRideScreen> createState() => _CustomerActiveRideScreenState();
}

class _CustomerActiveRideScreenState extends State<CustomerActiveRideScreen> {
  GoogleMapController? _mapController;
  Timer? _pollingTimer;

  LatLng? _driverLocation;
  late LatLng _pickupLocation;
  late LatLng _dropoffLocation;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  final PolylinePoints _polylinePoints = PolylinePoints(apiKey: ApiKeys.googleMapsKey);
  bool _isRouteDrawn = false;

  @override
  void initState() {
    super.initState();
    _initLocations();
    _fetchDriverLocation();
    // Poll every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchDriverLocation());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _initLocations() {
    double pLat = 22.7196; // Indore
    double pLng = 75.8577;
    
    final pickupData = widget.rideData['raw_pickup'] ?? widget.rideData['pickup'];
    if (pickupData is Map) {
      pLat = double.tryParse(pickupData['lat']?.toString() ?? '') ?? 22.7196;
      pLng = double.tryParse(pickupData['lng']?.toString() ?? '') ?? 75.8577;
    } else if (pickupData is String) {
      try {
        final map = jsonDecode(pickupData);
        if (map is Map) {
          pLat = double.tryParse(map['lat']?.toString() ?? '') ?? 22.7196;
          pLng = double.tryParse(map['lng']?.toString() ?? '') ?? 75.8577;
        }
      } catch (_) {}
    }
    _pickupLocation = LatLng(pLat, pLng);

    double dLat = 22.7196;
    double dLng = 75.8577;
    final destinationData = widget.rideData['raw_destination'] ?? widget.rideData['destination'];
    if (destinationData is Map) {
      dLat = double.tryParse(destinationData['lat']?.toString() ?? '') ?? 22.7196;
      dLng = double.tryParse(destinationData['lng']?.toString() ?? '') ?? 75.8577;
    } else if (destinationData is String) {
      try {
        final map = jsonDecode(destinationData);
        if (map is Map) {
          dLat = double.tryParse(map['lat']?.toString() ?? '') ?? 22.7196;
          dLng = double.tryParse(map['lng']?.toString() ?? '') ?? 75.8577;
        }
      } catch (_) {}
    }
    _dropoffLocation = LatLng(dLat, dLng);
  }

  Future<void> _fetchDriverLocation() async {
    final driverId = widget.rideData['assignedDriverId'];
    if (driverId == null) return;

    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/driver/location/$driverId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['location'] != null) {
          final lat = double.tryParse(data['location']['lat'].toString());
          final lng = double.tryParse(data['location']['lng'].toString());
          
          if (lat != null && lng != null) {
            if (mounted) {
              setState(() {
                _driverLocation = LatLng(lat, lng);
              });
              _updateMap();
              if (!_isRouteDrawn) {
                _drawRoute();
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error polling driver location: $e');
    }
  }

  Future<void> _drawRoute() async {
    if (_driverLocation == null) return;
    
    // Draw route once from driver to pickup
    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
          origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
          destination: PointLatLng(_pickupLocation.latitude, _pickupLocation.longitude),
          mode: TravelMode.driving
      )
    );

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = [];
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blueAccent,
            width: 5,
          )
        };
        _isRouteDrawn = true;
      });
      _focusMap();
    }
  }

  void _updateMap() {
    if (_driverLocation == null) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Driver Location'),
        ),
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      };
    });
  }

  void _focusMap() {
    if (_mapController != null && _driverLocation != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            _driverLocation!.latitude < _pickupLocation.latitude ? _driverLocation!.latitude : _pickupLocation.latitude,
            _driverLocation!.longitude < _pickupLocation.longitude ? _driverLocation!.longitude : _pickupLocation.longitude,
          ),
          northeast: LatLng(
            _driverLocation!.latitude > _pickupLocation.latitude ? _driverLocation!.latitude : _pickupLocation.latitude,
            _driverLocation!.longitude > _pickupLocation.longitude ? _driverLocation!.longitude : _pickupLocation.longitude,
          ),
        ),
        50,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Map Background
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _driverLocation ?? _pickupLocation, zoom: 15.0),
            markers: _markers.isEmpty 
              ? {
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: _pickupLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                    infoWindow: const InfoWindow(title: 'Pickup'),
                  )
                }
              : _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.primaryContainer),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'LIVE TRACKING',
                      style: GoogleFonts.nunito(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer
                ],
              ),
            ),
          ),

          // Bottom Sheet Info
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceContainerHighest,
                          shape: BoxShape.circle
                        ),
                        child: const Icon(Icons.person, color: AppTheme.primaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.rideData['driver_name'] ?? 'Your Driver', style: Theme.of(context).textTheme.headlineSmall),
                          Text('ID: ${widget.rideData['displayId'] ?? widget.rideData['id'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.onSurfaceVariant)),
                          const Text('Parigo EV Pilot', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.info, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Driver location updates every 10 seconds automatically.',
                          style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SafeArea(child: SizedBox(height: 8)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
