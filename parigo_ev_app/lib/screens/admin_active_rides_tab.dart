import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import 'admin_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AdminActiveRidesTab extends StatefulWidget {
  const AdminActiveRidesTab({super.key});

  @override
  State<AdminActiveRidesTab> createState() => _AdminActiveRidesTabState();
}

class _AdminActiveRidesTabState extends State<AdminActiveRidesTab> {
  bool _isLoadingActive = true;
  bool _isLoadingCompleted = true;
  List<dynamic> _activeRides = [];
  List<dynamic> _completedRides = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveRides();
    _fetchCompletedRides();
  }

  Future<void> _fetchActiveRides() async {
    setState(() => _isLoadingActive = true);
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/admin/rides/active'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _activeRides = data['rides'] ?? [];
          _isLoadingActive = false;
        });
      } else {
        throw Exception('Failed to load active rides');
      }
    } catch (e) {
      print('Error loading active rides: $e');
      setState(() => _isLoadingActive = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch active rides.')),
        );
      }
    }
  }

  Future<void> _fetchCompletedRides() async {
    setState(() => _isLoadingCompleted = true);
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/admin/rides/completed'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _completedRides = data['rides'] ?? [];
          _isLoadingCompleted = false;
        });
      } else {
        throw Exception('Failed to load completed rides');
      }
    } catch (e) {
      print('Error loading completed rides: $e');
      setState(() => _isLoadingCompleted = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch completed rides.')),
        );
      }
    }
  }

  void _refreshAll() {
    _fetchActiveRides();
    _fetchCompletedRides();
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
          _fetchActiveRides();
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

  String _getLocationDescription(dynamic loc) {
    if (loc is Map && loc['description'] != null) {
      return loc['description'];
    } else if (loc is String) {
      return loc;
    }
    return 'Unknown Location';
  }

  Widget _buildActiveRidesList() {
    if (_isLoadingActive) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryContainer));
    }
    if (_activeRides.isEmpty) {
      return const Center(
        child: Text('No active rides right now.',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _fetchActiveRides(),
      color: AppTheme.primaryContainer,
      backgroundColor: AppTheme.surfaceContainer,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _activeRides.length,
        itemBuilder: (context, index) {
          final ride = _activeRides[index];
          final pDesc = _getLocationDescription(ride['pickup']);
          final dDesc = _getLocationDescription(ride['destination']);
          final bool isInProgress = ride['status'] == 'IN_PROGRESS';
          final Color statusColor = isInProgress ? Colors.greenAccent : Colors.blueAccent;

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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            ride['status'] ?? 'ALLOTTED',
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ),
                        Text(
                          '₹${ride['estimatedFare'] ?? '---'}',
                          style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.my_location, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(pDesc, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14))),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9),
                      child: Align(alignment: Alignment.centerLeft, child: SizedBox(height: 12, child: VerticalDivider(color: AppTheme.outline))),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primaryContainer, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(dDesc, style: const TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outline),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: AppTheme.onSurfaceVariant, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Driver Name: ${ride['driverName'] ?? 'Unknown'}',
                                    style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, color: AppTheme.onSurfaceVariant, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Customer Name: ${ride['customerName'] ?? 'Unknown'}',
                                    style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        child: const Text('FORCE CANCEL RIDE',
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
    );
  }

  Widget _buildCompletedRidesList() {
    if (_isLoadingCompleted) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryContainer));
    }
    if (_completedRides.isEmpty) {
      return const Center(
        child: Text('No completed rides yet.',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _fetchCompletedRides(),
      color: AppTheme.primaryContainer,
      backgroundColor: AppTheme.surfaceContainer,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _completedRides.length,
        itemBuilder: (context, index) {
          final ride = _completedRides[index];
          final pDesc = _getLocationDescription(ride['pickup']);
          final dDesc = _getLocationDescription(ride['destination']);
          
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ),
                        Text(
                          '₹${ride['estimatedFare'] ?? '---'}',
                          style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.my_location, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(pDesc, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14))),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9),
                      child: Align(alignment: Alignment.centerLeft, child: SizedBox(height: 12, child: VerticalDivider(color: AppTheme.outline))),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primaryContainer, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(dDesc, style: const TextStyle(color: AppTheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: AppTheme.primary, size: 16),
                              const SizedBox(width: 8),
                              Text('Customer: ${ride['customerDetails'] != null ? ride['customerDetails']['name'] : (ride['customerPhone'] ?? 'Unknown')}', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.drive_eta, color: AppTheme.primaryContainer, size: 16),
                              const SizedBox(width: 8),
                              Text('Driver: ${ride['driverDetails'] != null ? ride['driverDetails']['name'] : (ride['assignedDriverId'] ?? 'Unknown')}', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.payment, color: Colors.greenAccent, size: 16),
                              const SizedBox(width: 8),
                              Text('Payment: ${ride['paymentMethod'] ?? 'CASH'}', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          title: Text('Rides Management',
              style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.onSurface),
              onPressed: _refreshAll,
            )
          ],
          bottom: const TabBar(
            labelColor: AppTheme.primaryContainer,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            indicatorColor: AppTheme.primaryContainer,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildActiveRidesList(),
              _buildCompletedRidesList(),
            ],
          ),
        ),
      ),
    );
  }
}
