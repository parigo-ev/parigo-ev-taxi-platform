import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import 'support_screen.dart';
import 'about_parigo_ev_screen.dart';
import 'trip_history_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class DriverProfileTab extends StatefulWidget {
  const DriverProfileTab({super.key});

  @override
  State<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<DriverProfileTab> {
  bool _isLoading = true;
  String _name = 'Loading...';
  String _vehicleType = 'Loading...';
  String _licensePlate = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final phone = UserSession().phone;
    if (phone == null || phone.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/driver/profile/$phone'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _name = data['name'] ?? 'Driver';
            _vehicleType = data['vehicle_type'] ?? 'Unknown Vehicle';
            _licensePlate = data['license_number'] ?? 'Unknown License';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching driver profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryContainer));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100, top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Profile Header
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryContainer, width: 2),
            ),
            child: const CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.surfaceContainerHighest,
              child: Icon(Icons.person, size: 50, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(_name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.orangeAccent, size: 18),
                SizedBox(width: 8),
                Text('4.9 Rating',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 2. Vehicle Info
          Align(
            alignment: Alignment.centerLeft,
            child: Text('VEHICLE',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: AppTheme.primary, letterSpacing: 2)),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.electric_car,
                      color: AppTheme.primaryContainer, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_vehicleType,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(_licensePlate,
                          style: const TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              letterSpacing: 1.5)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 3. Settings Menu
          Align(
            alignment: Alignment.centerLeft,
            child: Text('SETTINGS',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: AppTheme.primary, letterSpacing: 2)),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildListTile(Icons.history, 'Trip History', context, const TripHistoryScreen(role: 'Driver')),
                const Divider(color: AppTheme.outline, height: 1),
                _buildListTile(Icons.ev_station, 'Saved Charging Stations', context, null),
                const Divider(color: AppTheme.outline, height: 1),
                _buildListTile(Icons.support_agent, 'Help & Support', context, const SupportScreen()),
                const Divider(color: AppTheme.outline, height: 1),
                _buildListTile(Icons.info_outline, 'About Parigo EV', context, const AboutParigoEvScreen()),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 4. Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                // Clear session and sign out from Firebase
                await FirebaseAuth.instance.signOut();
                await UserSession().clear();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('LOGOUT',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, BuildContext context, Widget? destination) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.onSurfaceVariant),
      title: Text(title, style: const TextStyle(color: AppTheme.onSurface)),
      trailing: const Icon(Icons.arrow_forward_ios,
          color: AppTheme.onSurfaceVariant, size: 16),
      onTap: () {
        if (destination != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feature coming soon!')),
          );
        }
      },
    );
  }
}
