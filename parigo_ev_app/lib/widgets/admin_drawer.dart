import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/admin_coupons_screen.dart';
import '../core/user_session.dart';
import '../screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/api_constants.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AdminDrawer extends StatefulWidget {
  const AdminDrawer({super.key});

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> {
  String _adminName = 'Loading...';
  String _adminPhone = '';

  @override
  void initState() {
    super.initState();
    _adminPhone = UserSession().phone;
    _fetchAdminProfile();
  }

  Future<void> _fetchAdminProfile() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/user/profile/$_adminPhone'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _adminName = data['name'] ?? 'Parigo Admin';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _adminName = 'Parigo Admin';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _adminName = 'Parigo Admin';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = AdminDashboardScreen.of(context);
    final currentIndex = dashboardState?.currentIndex ?? 0;

    return Drawer(
      backgroundColor: AppTheme.surfaceContainerHigh,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTheme.background,
                border: Border(bottom: BorderSide(color: AppTheme.outline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryContainer.withOpacity(0.2),
                    child: const Icon(Icons.admin_panel_settings,
                        size: 32, color: AppTheme.primaryContainer),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _adminName,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.primaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
            _buildMenuItem(
              context,
              icon: Icons.list_alt,
              title: 'Dispatch',
              index: 0,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            _buildMenuItem(
              context,
              icon: Icons.map,
              title: 'Live Map',
              index: 1,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            _buildMenuItem(
              context,
              icon: Icons.electric_car,
              title: 'Rides',
              index: 2,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            _buildMenuItem(
              context,
              icon: Icons.people,
              title: 'Fleet',
              index: 3,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            _buildMenuItem(
              context,
              icon: Icons.person_outline,
              title: 'Customers',
              index: 4,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            _buildMenuItem(
              context,
              icon: Icons.star_rate,
              title: 'Customer Feedback',
              index: 5,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            _buildMenuItem(
              context,
              icon: Icons.stars,
              title: 'Driver Feedback',
              index: 8,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            _buildMenuItem(
              context,
              icon: Icons.report_problem,
              title: 'Reports & Issues',
              index: 7,
              currentIndex: currentIndex,
              dashboardState: dashboardState,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(color: AppTheme.outline),
            ),
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications,
                      title: 'Notifications',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.local_offer,
                      title: 'Coupons',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminCouponsScreen()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.settings,
                      title: 'Settings',
                      index: 6,
                      currentIndex: currentIndex,
                      dashboardState: dashboardState,
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(color: AppTheme.outline),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                await UserSession().clear();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen(role: 'Admin')),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    int? index,
    int? currentIndex,
    dynamic dashboardState,
    VoidCallback? onTap,
  }) {
    final isSelected = index != null && currentIndex != null && index == currentIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? AppTheme.primaryContainer.withOpacity(0.15)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected
              ? AppTheme.primaryContainer
              : AppTheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryContainer : AppTheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap ?? () {
          if (index != null) {
            dashboardState?.setTab(index);
          }
          Navigator.pop(context); // Close the drawer
        },
      ),
    );
  }
}
