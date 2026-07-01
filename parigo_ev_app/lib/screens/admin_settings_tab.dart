import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import '../screens/login_screen.dart';
import 'admin_dashboard_screen.dart';
import '../widgets/add_admin_sheet.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  // Mock Settings State
  double _baseFare = 50.0;
  double _perKmRate = 18.0;
  bool _surgePricing = false;
  double _surgeMultiplier = 1.5;

  // Real backend capacity state
  double _maxBookingsPerSlot = 5.0;
  
  // Analytics state
  int _totalRides = 0;
  double _totalRevenue = 0.0;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await ApiClient.get(
          Uri.parse('${ApiConstants.baseUrl}/admin/settings/slot-capacity'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _maxBookingsPerSlot = data['maxBookingsPerSlot']?.toDouble() ?? 5.0;
        });
      }
    } catch (e) {
      print('Error fetching slot capacity: $e');
    }
    try {
      final analyticsResponse = await ApiClient.get(
          Uri.parse('${ApiConstants.baseUrl}/admin/analytics'));
      if (analyticsResponse.statusCode == 200) {
        final data = json.decode(analyticsResponse.body);
        setState(() {
          _totalRides = data['totalRides'] != null ? int.tryParse(data['totalRides'].toString()) ?? 0 : 0;
          _totalRevenue = data['totalRevenue'] != null ? double.tryParse(data['totalRevenue'].toString()) ?? 0.0 : 0.0;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load analytics: ${analyticsResponse.statusCode}')));
        }
      }
    } catch (e) {
      print('Error fetching analytics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/settings/slot-capacity'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'maxBookingsPerSlot': _maxBookingsPerSlot.toInt()}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Settings Saved Successfully!'),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save settings'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

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
        title: Text('Settings & Analytics',
            style: GoogleFonts.nunito(color: AppTheme.primaryContainer)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _fetchSettings,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Analytics Overview
              Text('Today\'s Performance',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Icon(Icons.account_balance_wallet,
                                color: AppTheme.primary, size: 28),
                            const SizedBox(height: 8),
                            const Text('Revenue',
                                style: TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('₹${_totalRevenue.toStringAsFixed(0)}',
                                style: GoogleFonts.nunito(
                                    color: AppTheme.onSurface, fontSize: 22)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Icon(Icons.electric_car,
                                color: AppTheme.primaryContainer, size: 28),
                            const SizedBox(height: 8),
                            const Text('Completed Rides',
                                style: TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('$_totalRides',
                                style: GoogleFonts.nunito(
                                    color: AppTheme.onSurface, fontSize: 22)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 2. Fleet Capacity Control (NEW FEATURE)
              Text('Fleet Capacity Control',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppTheme.primary)),
              const SizedBox(height: 16),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Max Bookings per Slot',
                                    style: TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'Limits the number of cars customers can book in a single hour.',
                                    style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('${_maxBookingsPerSlot.toInt()} Cars',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Slider(
                        value: _maxBookingsPerSlot,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        activeColor: AppTheme.primary,
                        onChanged: (val) =>
                            setState(() => _maxBookingsPerSlot = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 3. Dynamic Pricing Controls
              Text('Dynamic Pricing Controls',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Base Fare (₹)',
                                    style: TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text('Starting price for all rides',
                                    style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('₹${_baseFare.toInt()}',
                              style: const TextStyle(
                                  color: AppTheme.primaryContainer,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _baseFare,
                        min: 30,
                        max: 100,
                        divisions: 14,
                        activeColor: AppTheme.primaryContainer,
                        onChanged: (val) => setState(() => _baseFare = val),
                      ),
                      const Divider(color: AppTheme.outline, height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Per KM Rate (₹)',
                                    style: TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text('Added cost per kilometer',
                                    style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('₹${_perKmRate.toInt()}',
                              style: const TextStyle(
                                  color: AppTheme.primaryContainer,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _perKmRate,
                        min: 10,
                        max: 30,
                        divisions: 20,
                        activeColor: AppTheme.primaryContainer,
                        onChanged: (val) => setState(() => _perKmRate = val),
                      ),
                      const Divider(color: AppTheme.outline, height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Surge Pricing',
                                    style: TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text('Enable during high demand',
                                    style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _surgePricing,
                            activeColor: AppTheme.primaryFixed,
                            onChanged: (val) =>
                                setState(() => _surgePricing = val),
                          )
                        ],
                      ),
                      if (_surgePricing) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Multiplier: ${_surgeMultiplier}x',
                                style: const TextStyle(
                                    color: AppTheme.primaryFixed,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Slider(
                                value: _surgeMultiplier,
                                min: 1.1,
                                max: 3.0,
                                divisions: 19,
                                activeColor: AppTheme.primaryFixed,
                                onChanged: (val) => setState(() =>
                                    _surgeMultiplier =
                                        double.parse(val.toStringAsFixed(1))),
                              ),
                            )
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 4. Admin Management (NEW FEATURE)
              Text('Admin Management',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: AppTheme.primaryContainer, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Add New Administrators',
                                    style: TextStyle(
                                        color: AppTheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text('Create access for new team members',
                                    style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.person_add, color: AppTheme.primaryContainer),
                          label: const Text('Add New Admin', style: TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primaryContainer),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => AddAdminSheet(
                                onAdminAdded: () {
                                  // Optionally do something after admin is added
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Save Global Settings',
                  onPressed: _saveSettings,
                ),
              ),
              const SizedBox(height: 24),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Logout',
                      style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    UserSession().clear();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen(role: 'Admin')),
                      (route) => false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
