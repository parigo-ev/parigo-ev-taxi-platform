import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import 'package:parigo_ev_app/core/api_client.dart';
import 'ride_details_screen.dart';

class AdminCustomerDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const AdminCustomerDetailsScreen({super.key, required this.customer});

  @override
  State<AdminCustomerDetailsScreen> createState() => _AdminCustomerDetailsScreenState();
}

class _AdminCustomerDetailsScreenState extends State<AdminCustomerDetailsScreen> {
  List<dynamic> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomerRides();
  }

  Future<void> _fetchCustomerRides() async {
    setState(() => _isLoading = true);
    try {
      final uid = widget.customer['uid'];
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/customer/rides/history?uid=$uid'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _rides = data['rides'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load rides');
      }
    } catch (e) {
      print('Error fetching customer rides: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown Date';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final bool isCompleted = ride['status'] == 'COMPLETED';
    final String status = ride['status'] ?? 'UNKNOWN';
    final String pickup = ride['pickup']?['description'] ?? 'Unknown Pickup';
    final String dropoff = ride['destination']?['description'] ?? 'Unknown Dropoff';
    final String fare = ride['finalFare'] != null 
        ? ride['finalFare'].toString() 
        : (ride['estimatedFare']?.toString() ?? '0.0');
    final waitPenalty = ride['customerWaitPenalty'];
    final latePenalty = ride['driverLatePenalty'];
    
    // Handle timestamp formatting safely
    String dateStr = 'Unknown Date';
    if (ride['createdAt'] != null) {
      if (ride['createdAt'] is String) {
        dateStr = _formatDate(ride['createdAt']);
      } else if (ride['createdAt'] is Map && ride['createdAt']['_seconds'] != null) {
         final date = DateTime.fromMillisecondsSinceEpoch(ride['createdAt']['_seconds'] * 1000);
         dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
      }
    }

    final String driverName = ride['driverDetails']?['name'] ?? 'Parigo EV Driver';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride, isAdmin: true)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${ride['displayId'] ?? ride['id']}', style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(dateStr, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.green : Colors.red),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, color: AppTheme.primary, size: 24),
                    Text(fare, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
                  ],
                ),
                if (waitPenalty != null && waitPenalty > 0)
                   Padding(
                     padding: const EdgeInsets.only(top: 4.0),
                     child: Text('+ ₹$waitPenalty Wait Time Charge', style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                   ),
                if (latePenalty != null && latePenalty > 0)
                   Padding(
                     padding: const EdgeInsets.only(top: 4.0),
                     child: Text('- ₹$latePenalty Punctuality Guarantee', style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                   ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.person, color: AppTheme.primaryContainer, size: 16),
                    const SizedBox(width: 8),
                    Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppTheme.outline),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, color: Colors.green, size: 12),
                    const SizedBox(width: 12),
                    Expanded(child: Text(pickup, style: const TextStyle(fontSize: 14))),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 5, top: 4, bottom: 4),
                  child: SizedBox(
                      height: 20,
                      child: VerticalDivider(color: AppTheme.onSurfaceVariant, thickness: 1)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 12),
                    const SizedBox(width: 12),
                    Expanded(child: Text(dropoff, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final String name = customer['name'] ?? 'Unknown Name';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Customer Details',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Customer Header Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppTheme.primaryContainer.withOpacity(0.1),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: AppTheme.primaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                      color: AppTheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 16, color: AppTheme.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Text(
                                      customer['phone'] ?? 'N/A',
                                      style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14)
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.email, size: 16, color: AppTheme.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        customer['email'] ?? 'No Email',
                                        style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.outline),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Joined Platform', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(customer['created_at']),
                                style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Rides', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _isLoading ? '--' : '${_rides.length}',
                                style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 18)
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            
            // Ride History Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ride History', style: GoogleFonts.nunito(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            // Rides List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryContainer))
                  : _rides.isEmpty
                      ? const Center(
                          child: Text(
                            'No rides found for this customer.',
                            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchCustomerRides,
                          color: AppTheme.primaryContainer,
                          backgroundColor: AppTheme.surfaceContainer,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _rides.length,
                            itemBuilder: (context, index) {
                              return _buildRideCard(_rides[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
