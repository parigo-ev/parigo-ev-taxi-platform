import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_constants.dart';
import '../core/api_keys.dart';
import '../core/user_session.dart';
import 'feedback_screen.dart';
import '../widgets/ride_chat_bottom_sheet.dart';
import '../widgets/location_disclosure_dialog.dart';
import 'package:parigo_ev_app/core/api_client.dart';


enum RideExecutionState {
  allotted, // En route to pickup
  arrived, // Waiting for customer
  inProgress, // Driving to destination
  completed // Ride finished
}

class DriverRideExecutionScreen extends StatefulWidget {
  final Map<String, dynamic>? rideData;
  const DriverRideExecutionScreen({super.key, this.rideData});

  @override
  State<DriverRideExecutionScreen> createState() =>
      _DriverRideExecutionScreenState();
}

class _DriverRideExecutionScreenState extends State<DriverRideExecutionScreen> with WidgetsBindingObserver {
  RideExecutionState _currentState = RideExecutionState.allotted;
  GoogleMapController? _mapController;

  LatLng? _driverLocation;
  late LatLng _pickupLocation;
  late LatLng _dropoffLocation;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  StreamSubscription<Position>? _positionStreamSubscription;
  final PolylinePoints _polylinePoints =
      PolylinePoints(apiKey: ApiKeys.googleMapsKey);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocations();
    if (widget.rideData != null) {
      final status = widget.rideData!['status'];
      if (status == 'ARRIVED') {
        _currentState = RideExecutionState.arrived;
        _startWaitTimer();
      } else if (status == 'IN_PROGRESS') {
        _currentState = RideExecutionState.inProgress;
      } else if (status == 'COMPLETED' || status == 'PENDING_PAYMENT') {
        _currentState = RideExecutionState.completed;
        _fetchUpdatedRideData();
      }
    }
  }

  Map<String, dynamic>? _updatedRideData;
  Timer? _waitTimer;
  int _waitSeconds = 0;

  void _startWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitSeconds++;
        });
      }
    });
  }

  String _formatWaitTime(int seconds) {
    if (seconds <= 180) {
      final remaining = 180 - seconds;
      final m = remaining ~/ 60;
      final s = remaining % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      final overtime = seconds - 180;
      final m = overtime ~/ 60;
      final s = overtime % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_driverLocation == null) {
        _startLocationUpdates();
      }
    }
  }

  Future<void> _fetchUpdatedRideData() async {
     try {
       final uid = UserSession().uid;
       final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/driver/rides/assigned?driverId=$uid'));
       if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         final rides = data['rides'] as List;
         // It might be in completed history now, not assigned. Let's fetch history if not found.
         var thisRide = rides.firstWhere((r) => r['id'] == widget.rideData!['id'], orElse: () => null);
         
         if (thisRide == null) {
            final histResponse = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/driver/rides/history?driverId=$uid'));
            if (histResponse.statusCode == 200) {
               final histData = jsonDecode(histResponse.body);
               final histRides = histData['rides'] as List;
               thisRide = histRides.firstWhere((r) => r['id'] == widget.rideData!['id'], orElse: () => null);
            }
         }

         if (thisRide != null && mounted) {
           setState(() {
              _updatedRideData = thisRide;
           });
         }
       }
     } catch (e) {
       print('Error fetching updated ride data: $e');
     }
  }

  void _initLocations() {
    if (widget.rideData != null && widget.rideData!['pickup'] != null) {
      _pickupLocation = LatLng(widget.rideData!['pickup']['lat'] ?? 28.6239,
          widget.rideData!['pickup']['lng'] ?? 77.2190);
    } else {
      _pickupLocation = const LatLng(28.6239, 77.2190);
    }

    if (widget.rideData != null && widget.rideData!['destination'] != null) {
      _dropoffLocation = LatLng(
          widget.rideData!['destination']['lat'] ?? 28.5939,
          widget.rideData!['destination']['lng'] ?? 77.2290);
    } else {
      _dropoffLocation = const LatLng(28.5939, 77.2290);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationUpdates();
    });
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('GPS is Disabled'),
            content: const Text('Please turn on your phone\'s GPS/Location Services so customers can see your live ETA.'),
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

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      // 1. Show Prominent Disclosure for Google Play / App Store compliance
      final accepted = await LocationDisclosureDialog.show(
        context,
        message: 'Parigo EV Driver collects location data to enable live ride tracking for customers and accurately calculate your ETA, even when the app is closed or not in use.',
      );
      
      if (accepted != true) return;

      if (permission == LocationPermission.deniedForever) {
        Geolocator.openAppSettings();
        return;
      }

      // 2. Request actual system permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      Geolocator.openAppSettings();
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _driverLocation = LatLng(position.latitude, position.longitude);
    });
    _updateMap();

    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, distanceFilter: 10))
        .listen((Position position) {
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
          _updateMap();
        });

        // Push location to backend
        if (widget.rideData != null &&
            widget.rideData!['assignedDriverId'] != null) {
          ApiClient.post(
                Uri.parse('${ApiConstants.baseUrl}/driver/location/update'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'driverId': widget.rideData!['assignedDriverId'],
                  'lat': position.latitude,
                  'lng': position.longitude,
                }),
              )
              .catchError((e) => print('Error pushing location: $e'));
        }
      }
    });
  }

  Future<void> _updateMap() async {
    if (_driverLocation == null) return;

    _markers = {
      Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
      Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange)),
      if (_currentState == RideExecutionState.inProgress ||
          _currentState == RideExecutionState.completed)
        Marker(
            markerId: const MarkerId('dropoff'),
            position: _dropoffLocation,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
    };

    LatLng targetDestination = (_currentState == RideExecutionState.inProgress)
        ? _dropoffLocation
        : _pickupLocation;

    if (_currentState != RideExecutionState.completed) {
      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
            origin: PointLatLng(
                _driverLocation!.latitude, _driverLocation!.longitude),
            destination: PointLatLng(
                targetDestination.latitude, targetDestination.longitude),
            mode: TravelMode.driving),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoordinates,
            color: _currentState == RideExecutionState.inProgress
                ? Colors.blue
                : Colors.orange,
            width: 5,
          )
        };
      }
    } else {
      _polylines = {};
    }

    if (mounted) setState(() {});
  }

  Future<void> _updateRideStatus(String newStatus) async {
    if (widget.rideData == null) return;
    try {
      await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/driver/rides/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rideId': widget.rideData!['id'],
          'status': newStatus,
        }),
      );
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  void _showOtpDialog() {
    final TextEditingController otpController = TextEditingController();
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            title: Text('Enter Customer OTP',
                style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
            content: TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(
                  color: AppTheme.onSurface, fontSize: 24, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '0000',
                hintStyle: TextStyle(color: AppTheme.onSurfaceVariant),
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryContainer)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL',
                    style: TextStyle(color: AppTheme.onSurfaceVariant)),
              ),
              PrimaryButton(
                text: 'VERIFY',
                onPressed: () {
                  final correctOtp =
                      widget.rideData?['otp']?.toString() ?? '1234';
                  if (otpController.text == correctOtp) {
                    Navigator.pop(context);
                    _waitTimer?.cancel();
                    setState(() {
                      _currentState = RideExecutionState.inProgress;
                    });
                    _updateMap();
                    _updateRideStatus('IN_PROGRESS');
                    _focusMap();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Invalid OTP'),
                        backgroundColor: Colors.red));
                  }
                },
              )
            ],
          );
        });
  }

  void _focusMap() {
    if (_mapController != null && _driverLocation != null) {
      LatLng targetDestination =
          (_currentState == RideExecutionState.inProgress)
              ? _dropoffLocation
              : _pickupLocation;
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            _driverLocation!.latitude < targetDestination.latitude
                ? _driverLocation!.latitude
                : targetDestination.latitude,
            _driverLocation!.longitude < targetDestination.longitude
                ? _driverLocation!.longitude
                : targetDestination.longitude,
          ),
          northeast: LatLng(
            _driverLocation!.latitude > targetDestination.latitude
                ? _driverLocation!.latitude
                : targetDestination.latitude,
            _driverLocation!.longitude > targetDestination.longitude
                ? _driverLocation!.longitude
                : targetDestination.longitude,
          ),
        ),
        50,
      ));
    }
  }

  void _advanceState() {
    setState(() {
      if (_currentState == RideExecutionState.allotted) {
        _currentState = RideExecutionState.arrived;
        _updateRideStatus('ARRIVED');
        _startWaitTimer();
      } else if (_currentState == RideExecutionState.arrived) {
        _showOtpDialog();
      } else if (_currentState == RideExecutionState.inProgress) {
        bool isPrepaid = widget.rideData?['isPrepaid'] == true;

        if (isPrepaid) {
          // Ride is already paid for! Skip to completed.
          _currentState = RideExecutionState.completed;
          _updateMap();
          _updateRideStatus('COMPLETED');

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => FeedbackScreen(
                      role: 'Driver',
                      rideId: widget.rideData?['id']?.toString() ?? 'unknown',
                      otherPartyName:
                          widget.rideData?['customerName'] ?? 'Customer',
                    )),
          );
        } else {
          // Change to pending payment
          _updateRideStatus('PENDING_PAYMENT');
          
          // Show waiting dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceContainerHigh,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 24),
                  Text('Waiting for Customer Payment...', style: GoogleFonts.nunito(color: AppTheme.onSurface, fontSize: 18)),
                ],
              ),
            )
          );

          // We should start polling for COMPLETED status to know when customer paid.
          _startPaymentPolling();
        }
      }
    });
  }

  Timer? _paymentPollTimer;
  void _startPaymentPolling() {
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (widget.rideData == null) return;
      try {
        // We can fetch the ride document from Firestore directly to check status
        // But we don't have firestore imported here. Let's create a quick API call if needed,
        // or just use the driver assigned rides endpoint to find this ride.
        final uid = UserSession().uid;
        final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/driver/rides/assigned?driverId=$uid'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rides = data['rides'] as List;
          final thisRide = rides.firstWhere((r) => r['id'] == widget.rideData!['id'], orElse: () => null);
          
          // If ride is gone from assigned (because it's completed) or status is COMPLETED
          if (thisRide == null || thisRide['status'] == 'COMPLETED') {
            timer.cancel();
            if (mounted) {
              Navigator.pop(context); // Close waiting dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => FeedbackScreen(
                          role: 'Driver',
                          rideId: widget.rideData?['id']?.toString() ?? 'unknown',
                          otherPartyName:
                              widget.rideData?['customerName'] ?? 'Customer',
                        )),
              );
            }
          }
        }
      } catch (e) {
        print('Error polling payment: $e');
      }
    });
  }


  Future<void> _launchMapsUrl(LatLng destination) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 100.0), // Shift below app bar area
        child: FloatingActionButton(
          backgroundColor: Colors.redAccent,
          onPressed: () async {
            final Uri url = Uri.parse(
                'whatsapp://send?phone=+918878587615'); // Company Head Admin
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not launch WhatsApp')));
            }
          },
          child: const Icon(Icons.sos, color: Colors.white, size: 30),
        ),
      ),
      body: Stack(
        children: [
          // 1. Google Map Background
          if (_driverLocation == null)
            const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
          else
            GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _driverLocation!, zoom: 15.0),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
                _focusMap();
              },
            ),

          // 2. Top App Bar (Floating)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.primaryContainer),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  GlassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      _getStateTitle(),
                      style: GoogleFonts.nunito(
                          color: _getStateColor(), fontSize: 16),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    child: IconButton(
                      icon: const Icon(Icons.sos, color: Colors.redAccent),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('SOS Alert Sent to Admin!')));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Execution Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5)),
                  ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Info
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHighest,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.person,
                            color: AppTheme.primaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              (widget.rideData != null && widget.rideData!['customerDetails'] != null)
                                  ? widget.rideData!['customerDetails']['name'] ?? 'Customer'
                                  : ((widget.rideData != null && widget.rideData!['uid'] != 'anonymous')
                                      ? (widget.rideData!['uid'] ?? 'Customer').toString()
                                      : 'Guest Customer'),
                              style: Theme.of(context).textTheme.headlineSmall),
                          const Row(
                            children: [
                              Icon(Icons.star,
                                  color: Colors.orangeAccent, size: 16),
                              SizedBox(width: 4),
                              Text('4.9',
                                  style: TextStyle(
                                      color: AppTheme.onSurfaceVariant)),
                            ],
                          )
                        ],
                      ),
                      const Spacer(),
                      CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        child: IconButton(
                          icon: const Icon(Icons.chat, color: Colors.blueAccent),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => RideChatBottomSheet(
                                rideId: widget.rideData?['id']?.toString() ?? '',
                                role: 'Driver',
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.greenAccent.withOpacity(0.2),
                        child: IconButton(
                          icon: const Icon(Icons.phone,
                              color: Colors.greenAccent),
                          onPressed: () async {
                              final phone = widget.rideData?['customerDetails']?['phone'] ?? widget.rideData?['customerPhone'] ?? '+910000000000';
                              final Uri launchUri = Uri(scheme: 'tel', path: phone);
                              if (await canLaunchUrl(launchUri)) {
                                await launchUrl(launchUri);
                              }
                          },
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Route Info
                  if (_currentState == RideExecutionState.arrived) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, color: _waitSeconds <= 180 ? Colors.orangeAccent : Colors.greenAccent),
                            const SizedBox(width: 8),
                            Text(
                              _waitSeconds <= 180 ? 'Waiting: ${_formatWaitTime(_waitSeconds)}' : 'Wait Penalty: +${_formatWaitTime(_waitSeconds)}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _waitSeconds <= 180 ? Colors.orangeAccent : Colors.greenAccent)
                            )
                          ]
                        )
                      )
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_currentState != RideExecutionState.completed) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.orange, width: 4))),
                            Container(
                                width: 2,
                                height: 40,
                                color: Colors.orange.withOpacity(0.5)),
                            Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.blue, width: 4))),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pickup Location',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _currentState ==
                                              RideExecutionState.allotted
                                          ? AppTheme.onSurface
                                          : AppTheme.onSurfaceVariant)),
                              const SizedBox(height: 38),
                              Row(
                                children: [
                                  if (_currentState ==
                                          RideExecutionState.allotted ||
                                      _currentState ==
                                          RideExecutionState.arrived) ...[
                                    const Icon(Icons.lock,
                                        color: AppTheme.onSurfaceVariant,
                                        size: 14),
                                    const SizedBox(width: 6),
                                    const Text('Destination hidden',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.onSurfaceVariant)),
                                  ] else
                                    Text('Dropoff Location',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _currentState ==
                                                    RideExecutionState
                                                        .inProgress
                                                ? AppTheme.onSurface
                                                : AppTheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (_currentState == RideExecutionState.completed) ...[
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.greenAccent, size: 64),
                          const SizedBox(height: 16),
                          Text('Ride Completed!',
                              style: GoogleFonts.nunito(
                                  fontSize: 24, color: Colors.greenAccent)),
                          const SizedBox(height: 8),
                          if (_updatedRideData?['customerWaitPenalty'] != null && _updatedRideData!['customerWaitPenalty'] > 0)
                             Text('+ ₹${_updatedRideData!['customerWaitPenalty']} Wait Time Charge', style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
                          if (_updatedRideData?['driverLatePenalty'] != null && _updatedRideData!['driverLatePenalty'] > 0)
                             Text('- ₹${_updatedRideData!['driverLatePenalty']} Late Discount (50% Company Covered)', style: const TextStyle(color: Colors.greenAccent, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                              '₹${_updatedRideData?['finalFare'] ?? widget.rideData?['estimatedFare'] ?? '450'} to be collected',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onSurface)),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.qr_code_2,
                                size: 120, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          const Text('Company UPI QR',
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],

                  // Action Buttons
                  if (_currentState == RideExecutionState.allotted ||
                      _currentState == RideExecutionState.inProgress) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.navigation,
                            color: Colors.blueAccent),
                        label: Text(
                            _currentState == RideExecutionState.allotted
                                ? 'NAVIGATE TO PICKUP'
                                : 'NAVIGATE TO DROPOFF',
                            style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.blueAccent, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          _launchMapsUrl(
                              _currentState == RideExecutionState.allotted
                                  ? _pickupLocation
                                  : _dropoffLocation);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: _getButtonText(),
                      onPressed: () {
                        if (_currentState == RideExecutionState.completed) {
                          Navigator.pop(context); // Go back home
                        } else {
                          _advanceState();
                        }
                      },
                    ),
                  ),
                  const SafeArea(child: SizedBox(height: 8)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  String _getStateTitle() {
    switch (_currentState) {
      case RideExecutionState.allotted:
        return 'EN ROUTE TO PICKUP';
      case RideExecutionState.arrived:
        return 'WAITING FOR CUSTOMER';
      case RideExecutionState.inProgress:
        return 'DRIVING TO DROPOFF';
      case RideExecutionState.completed:
        return 'RIDE FINISHED';
    }
  }

  Color _getStateColor() {
    switch (_currentState) {
      case RideExecutionState.allotted:
        return Colors.orangeAccent;
      case RideExecutionState.arrived:
        return Colors.yellowAccent;
      case RideExecutionState.inProgress:
        return Colors.blueAccent;
      case RideExecutionState.completed:
        return Colors.greenAccent;
    }
  }

  String _getButtonText() {
    switch (_currentState) {
      case RideExecutionState.allotted:
        return 'ARRIVED AT PICKUP';
      case RideExecutionState.arrived:
        return 'START RIDE & NAVIGATE';
      case RideExecutionState.inProgress:
        return 'COMPLETE RIDE';
      case RideExecutionState.completed:
        return 'RETURN TO DASHBOARD';
    }
  }
}
