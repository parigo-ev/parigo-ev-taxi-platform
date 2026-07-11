import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import '../widgets/primary_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/pre_booking_payment_sheet.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class ScheduleRideScreen extends StatefulWidget {
  final Map<String, dynamic> pickup;
  final Map<String, dynamic> destination;

  const ScheduleRideScreen({
    super.key,
    required this.pickup,
    required this.destination,
  });

  @override
  State<ScheduleRideScreen> createState() => _ScheduleRideScreenState();
}

class _ScheduleRideScreenState extends State<ScheduleRideScreen> {
  DateTime? _selectedDate;
  String? _selectedTime;
  String? _selectedSubTime;
  String? _estimatedFare;
  String? _originalFare;
  String? _distanceKm;
  bool _isLoadingFare = true;
  bool _isScheduling = false;

  // Capacity state
  Map<String, int> _bookedSlots = {};
  int _maxCapacity = 5;

  // Coupon state
  final _couponController = TextEditingController();
  String? _appliedCoupon;
  double _couponDiscount = 0.0;
  bool _isCouponApplied = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _fetchFareEstimate();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCouponCode(String code) async {
    if (_originalFare == null) return;
    final double baseFare = double.tryParse(_originalFare!) ?? 0.0;
    if (baseFare == 0.0) return;

    final cleanCode = code.trim().toUpperCase();
    
    setState(() {
      _couponError = null;
      _isLoadingFare = true;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/ride/coupon/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': cleanCode,
          'phone': UserSession().phone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String discountType = data['discountType'];
        final double discountValue = (data['discountValue'] as num).toDouble();

        double discount = 0.0;
        if (discountType == 'PERCENTAGE') {
          discount = baseFare * (discountValue / 100);
        } else {
          discount = discountValue;
        }

        if (discount > baseFare) discount = baseFare;

        setState(() {
          _appliedCoupon = cleanCode;
          _couponDiscount = discount;
          _isCouponApplied = true;
          _couponError = null;
          final double finalFare = baseFare - discount;
          _estimatedFare = finalFare.round().toString();
          _isLoadingFare = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _couponError = data['message'] ?? 'Invalid coupon code';
          _appliedCoupon = null;
          _couponDiscount = 0.0;
          _isCouponApplied = false;
          _estimatedFare = _originalFare;
          _isLoadingFare = false;
        });
      }
    } catch (e) {
      setState(() {
        _couponError = 'Connection error: $e';
        _appliedCoupon = null;
        _couponDiscount = 0.0;
        _isCouponApplied = false;
        _estimatedFare = _originalFare;
        _isLoadingFare = false;
      });
    }
  }

  void _clearCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _isCouponApplied = false;
      _couponError = null;
      _couponController.clear();
      _estimatedFare = _originalFare;
    });
  }

  Future<void> _fetchFareEstimate() async {
    try {
      final response = await ApiClient
          .post(
            Uri.parse('${ApiConstants.baseUrl}/ride/estimate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pickup': {
                'lat': widget.pickup['lat'],
                'lng': widget.pickup['lng'],
              },
              'destination': {
                'lat': widget.destination['lat'],
                'lng': widget.destination['lng'],
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _estimatedFare = data['estimated_fare'].toString();
            _originalFare = data['estimated_fare'].toString();
            _distanceKm = data['distance_km'].toString();
            _isLoadingFare = false;
            if (_isCouponApplied && _couponController.text.isNotEmpty) {
              _applyCouponCode(_couponController.text);
            }
          });
        }
      } else {
        throw Exception('Failed to load fare');
      }
    } catch (e) {
      print('Error getting estimate: $e');
      if (mounted) {
        setState(() {
          _isLoadingFare = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not fetch fare estimate. Please check connection.')),
        );
      }
    }
  }

  String _formatDate(DateTime d) {
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final List<String> weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  Future<void> _pickDate() async {
    final List<DateTime> next7Days =
        List.generate(7, (index) => DateTime.now().add(Duration(days: index)));

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        int tempIndex = 0;
        return Container(
          height: 350,
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
          child: Column(
            children: [
              Text('Select Date',
                  style: GoogleFonts.nunito(
                      fontSize: 18, color: AppTheme.primaryContainer)),
              const SizedBox(height: 24),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 60,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.5,
                  onSelectedItemChanged: (index) => tempIndex = index,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: next7Days.length,
                    builder: (context, index) {
                      final date = next7Days[index];
                      String label = '';
                      if (index == 0)
                        label = 'Today';
                      else if (index == 1)
                        label = 'Tomorrow';
                      else
                        label = _formatDate(date);

                      return Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                              color: AppTheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Confirm Date',
                  onPressed: () => Navigator.pop(context, tempIndex),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedIndex != null) {
      setState(() {
        _selectedDate = next7Days[selectedIndex];
        _selectedTime = null; // Reset time to ensure validity
        _selectedSubTime = null;
      });
    }
  }

  Future<void> _fetchSlotAvailability(String dateString) async {
    try {
      final response = await ApiClient.get(Uri.parse(
          '${ApiConstants.baseUrl}/ride/slot-availability?date=$dateString'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _maxCapacity = data['maxCapacity'] ?? 5;
          _bookedSlots = Map<String, int>.from(data['bookedSlots'] ?? {});
        });
      }
    } catch (e) {
      print('Error fetching availability: $e');
    }
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date first')));
      return;
    }

    // Show loading
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child:
                CircularProgressIndicator(color: AppTheme.primaryContainer)));
    await _fetchSlotAvailability(_formatDate(_selectedDate!));
    if (mounted) Navigator.pop(context); // hide loading

    final now = DateTime.now();
    final isToday = _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;

    int startHour = 0; // Default to 12 AM for future days
    if (isToday) {
      startHour = now.hour + 1;
    }

    if (startHour > 23) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No slots left for today. Please select tomorrow.')));
      return;
    }

    List<String> timeSlots = [];
    for (int i = startHour; i <= 23; i++) {
      String formatHour(int h) {
        if (h == 24) return '12:00 AM'; // Midnight wrap-around
        final period = h >= 12 && h < 24 ? 'PM' : 'AM';
        int hr = h % 12;
        if (hr == 0) hr = 12;
        return '${hr.toString().padLeft(2, '0')}:00 $period';
      }

      timeSlots.add('${formatHour(i)} - ${formatHour(i + 1)}');
    }

    final selectedSlotIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        int tempIndex = 0;
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            height: 400,
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
            child: Column(
              children: [
                Text('Select Time Slot',
                    style: GoogleFonts.nunito(
                        fontSize: 18, color: AppTheme.primaryContainer)),
                const SizedBox(height: 8),
                Text('Max $_maxCapacity cars per slot',
                    style: const TextStyle(
                        color: AppTheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 65,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 1.5,
                    onSelectedItemChanged: (index) => tempIndex = index,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: timeSlots.length,
                      builder: (context, index) {
                        final slot = timeSlots[index];
                        final booked = _bookedSlots[slot] ?? 0;
                        final isFull = booked >= _maxCapacity;

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slot,
                                style: TextStyle(
                                  color: isFull
                                      ? AppTheme.onSurfaceVariant
                                          .withOpacity(0.5)
                                      : AppTheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: isFull
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (isFull)
                                const Text('SLOT FULL',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold))
                              else if (booked > 0)
                                Text('$booked/$_maxCapacity Booked',
                                    style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 10)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Confirm Time',
                    onPressed: () {
                      final slot = timeSlots[tempIndex];
                      if ((_bookedSlots[slot] ?? 0) >= _maxCapacity) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'This slot is fully booked. Please select another time.'),
                            backgroundColor: Colors.red));
                      } else {
                        Navigator.pop(context, tempIndex);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    if (selectedSlotIndex != null) {
      setState(() {
        _selectedTime = timeSlots[selectedSlotIndex];
        _selectedSubTime = null;
      });
    }
  }

  Future<void> _pickSubTime() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time slot first')));
      return;
    }

    final parts = _selectedTime!.split(' - ');
    if (parts.isEmpty) return;
    
    final startStr = parts[0]; 
    final isPM = startStr.contains('PM');
    final baseHourStr = startStr.split(':')[0]; 
    final period = isPM ? 'PM' : 'AM';
    
    List<String> subTimes = [];
    for (int m = 0; m < 60; m += 15) {
      subTimes.add('$baseHourStr:${m.toString().padLeft(2, '0')} $period');
    }

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        int tempIndex = 0;
        return Container(
          height: 350,
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
          child: Column(
            children: [
              Text('Select Sub Time',
                  style: GoogleFonts.nunito(
                      fontSize: 18, color: AppTheme.primaryContainer)),
              const SizedBox(height: 24),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 60,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.5,
                  onSelectedItemChanged: (index) => tempIndex = index,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: subTimes.length,
                    builder: (context, index) {
                      return Center(
                        child: Text(
                          subTimes[index],
                          style: const TextStyle(
                              color: AppTheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Confirm Sub Time',
                  onPressed: () => Navigator.pop(context, tempIndex),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedIndex != null) {
      setState(() {
        _selectedSubTime = subTimes[selectedIndex];
      });
    }
  }

  void _confirmBooking() {
    if (_selectedDate == null || _selectedTime == null || _selectedSubTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date, time slot, and exact sub-time')),
      );
      return;
    }

    final double baseFare = double.tryParse(_estimatedFare ?? '0') ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PreBookingPaymentSheet(
        baseFare: baseFare,
        onPaymentConfirmed: (method, isPrepaid, {razorpayPaymentId, razorpaySignature, razorpayOrderId}) {
          _scheduleRide(
            method,
            isPrepaid,
            razorpayPaymentId: razorpayPaymentId,
            razorpaySignature: razorpaySignature,
            razorpayOrderId: razorpayOrderId,
          );
        },
      ),
    );
  }

  Future<void> _scheduleRide(
    String paymentMethod, 
    bool isPrepaid, {
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? razorpayOrderId,
  }) async {
    setState(() {
      _isScheduling = true;
    });

    try {
      final body = <String, dynamic>{
        'pickup': {
          'lat': widget.pickup['lat'],
          'lng': widget.pickup['lng'],
          'description': widget.pickup['description'],
        },
        'destination': {
          'lat': widget.destination['lat'],
          'lng': widget.destination['lng'],
          'description': widget.destination['description'],
        },
        'scheduledDate': _selectedDate!.toIso8601String(),
        'scheduledTime': _selectedTime,
        'exactTime': _selectedSubTime,
        'estimatedFare': _estimatedFare,
        'distanceKm': _distanceKm,
        'uid': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        'paymentMethod': paymentMethod,
        'isPrepaid': isPrepaid,
        if (_appliedCoupon != null) 'couponCode': _appliedCoupon,
      };

      if (razorpayPaymentId != null) body['razorpay_payment_id'] = razorpayPaymentId;
      if (razorpaySignature != null) body['razorpay_signature'] = razorpaySignature;
      if (razorpayOrderId != null) body['razorpay_order_id'] = razorpayOrderId;

      final response = await ApiClient
          .post(
            Uri.parse('${ApiConstants.baseUrl}/ride/schedule'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _isScheduling = false;
        });
      }

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String otp = data['otp'] ?? '0000';

        if (mounted) {
          _showSuccessOtpDialog(otp);
        }
      } else {
        throw Exception('Failed to schedule ride');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScheduling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling ride: $e')),
        );
      }
    }
  }

  void _showSuccessOtpDialog(String otp) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface, // Solid background
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 64),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Awesome!',
                        style: GoogleFonts.nunito(
                            fontSize: 24, color: AppTheme.primaryContainer),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your EV ride has been successfully confirmed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'YOUR RIDE OTP',
                        style: TextStyle(
                            color: AppTheme.primaryFixed,
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  AppTheme.primaryContainer.withOpacity(0.5)),
                        ),
                        child: Text(
                          otp,
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                              letterSpacing: 8),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Please share this code with your driver before starting the ride.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          text: 'Done',
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(context).pop(); // Go back to Home
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Schedule Ride',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Locations
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.my_location,
                                color: AppTheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    widget.pickup['description'] ??
                                        'Current Location',
                                    style: const TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 16))),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                  height: 20,
                                  child: VerticalDivider(
                                      color: AppTheme.outline))),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: AppTheme.primaryContainer, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    widget.destination['description'] ??
                                        'Destination',
                                    style: const TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Fare & Distance
                const Text('ESTIMATED FARE',
                    style: TextStyle(
                        color: AppTheme.primaryFixed,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Price',
                                style: TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            _isLoadingFare
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text('₹${_estimatedFare ?? '---'}',
                                    style: const TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Distance',
                                style: TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            _isLoadingFare
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text('${_distanceKm ?? '--'} km',
                                    style: const TextStyle(
                                        color: AppTheme.primaryContainer,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Date & Time Picker
                const Text('SELECT DATE & TIME',
                    style: TextStyle(
                        color: AppTheme.primaryFixed,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_month,
                                    color: AppTheme.primaryContainer, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                    _selectedDate != null
                                        ? (_selectedDate!.day ==
                                                DateTime.now().day
                                            ? 'Today'
                                            : (_selectedDate!.day ==
                                                    DateTime.now()
                                                        .add(const Duration(
                                                            days: 1))
                                                        .day
                                                ? 'Tomorrow'
                                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'))
                                        : 'Select Date',
                                    style: const TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                const Icon(Icons.access_time,
                                    color: AppTheme.primaryContainer, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedTime ?? 'Select Time',
                                  style: const TextStyle(
                                      color: AppTheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickSubTime,
                  borderRadius: BorderRadius.circular(16),
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.more_time, color: AppTheme.primaryContainer, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            _selectedSubTime ?? 'Select Sub Time',
                            style: const TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Coupon Code Section
                const Text('APPLY COUPON',
                    style: TextStyle(
                        color: AppTheme.primaryFixed,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_offer, color: AppTheme.primaryContainer, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _couponController,
                              style: const TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'Enter coupon code',
                                hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                errorText: _couponError,
                                errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                              ),
                              enabled: !_isCouponApplied,
                            ),
                          ),
                          _isCouponApplied
                              ? TextButton(
                                  onPressed: _clearCoupon,
                                  child: const Text('REMOVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                )
                              : TextButton(
                                  onPressed: () {
                                    if (_couponController.text.isNotEmpty) {
                                      _applyCouponCode(_couponController.text);
                                    }
                                  },
                                  child: const Text('APPLY', style: TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold)),
                                ),
                        ],
                      ),
                      if (_isCouponApplied) ...[
                        const Divider(color: AppTheme.outline),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Coupon "$_appliedCoupon" Applied!',
                              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '- ₹${_couponDiscount.round()}',
                              style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Apply coupon code to get discount benefits.',
                        style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _isScheduling
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryContainer))
                    : PrimaryButton(
                        text: 'Confirm Booking',
                        onPressed: _confirmBooking,
                      ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
