import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'support_screen.dart';
import 'about_parigo_ev_screen.dart';
import 'trip_history_screen.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import 'package:parigo_ev_app/core/api_client.dart';
import '../services/push_notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _name = 'Add Your Name';
  String _phone = '';
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _phone = UserSession().phone;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get(
          Uri.parse('${ApiConstants.baseUrl}/user/profile/$_phone'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _name = data['name'] ?? 'Add Your Name';
          _profilePictureUrl = data['profile_picture_url'];
        });
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Profile',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Avatar & Name
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.primaryContainer, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryContainer.withOpacity(0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          backgroundColor: AppTheme.surfaceContainerHighest,
                          backgroundImage: _profilePictureUrl != null &&
                                  _profilePictureUrl!.isNotEmpty
                              ? MemoryImage(base64Decode(
                                  _profilePictureUrl!.split(',').last))
                              : null,
                          child: _profilePictureUrl == null ||
                                  _profilePictureUrl!.isEmpty
                              ? const Icon(Icons.person,
                                  size: 60, color: AppTheme.primary)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator(
                              color: AppTheme.primaryContainer)
                          : Text(
                              _name,
                              style: GoogleFonts.nunito(
                                fontSize: 28,
                                color: AppTheme.onSurface,
                              ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        _phone.isEmpty ? '+91 98765 43210' : _phone,
                        style: const TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Options List
                GlassCard(
                  child: Column(
                    children: [
                      _buildProfileOption(context, Icons.person_outline,
                          'Edit Profile', const EditProfileScreen()),
                      const Divider(
                          color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildProfileOption(
                          context,
                          Icons.history,
                          'Trip History',
                          const TripHistoryScreen(role: 'Customer')),
                      const Divider(
                          color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildProfileOption(context, Icons.notifications_outlined,
                          'Notifications', const NotificationsScreen()),
                      const Divider(
                          color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildProfileOption(context, Icons.help_outline,
                          'Help & Support', const SupportScreen()),
                      const Divider(
                          color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildProfileOption(context, Icons.info_outline,
                          'About Parigo EV', const AboutParigoEvScreen()),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text('LOG OUT',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.surfaceContainer,
                          title: const Text('Log Out?',
                              style: TextStyle(
                                  color: AppTheme.onSurface,
                                  fontWeight: FontWeight.bold)),
                          content: const Text(
                            'Are you sure you want to log out of your account?',
                            style: TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      color: AppTheme.primaryContainer)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Log Out',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      await _logout();
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Delete Account Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('DELETE ACCOUNT',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    onPressed: _deleteAccount,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    // Push-token cleanup is optional. It must never prevent a person from
    // leaving their account when push is unavailable or the network is slow.
    await PushNotificationService()
        .unregisterTokenForCurrentUser()
        .timeout(const Duration(seconds: 6), onTimeout: () {});

    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('Firebase sign-out failed: $error');
    } finally {
      await UserSession().clear();
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) => const LoginScreen(role: 'Customer')),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainer,
        title: const Text('Delete Account?',
            style: TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to completely delete your account? This action cannot be undone, and all your data will be permanently removed.',
          style: TextStyle(color: AppTheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.primaryContainer)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.delete(
          Uri.parse('${ApiConstants.baseUrl}/user/delete/$_phone'));

      if (response.statusCode == 200) {
        await PushNotificationService().unregisterTokenForCurrentUser();
        await UserSession().clear();
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => const LoginScreen(role: 'Customer')),
            (Route<dynamic> route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Account deleted successfully'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Failed to delete account');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProfileOption(
      BuildContext context, IconData icon, String title, Widget? screen) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryContainer),
      title: Text(title,
          style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 16, color: AppTheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      onTap: () async {
        if (screen != null) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
          if (result == true && title == 'Edit Profile') {
            _fetchProfile(); // Refresh profile if it was edited
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title section coming soon')));
        }
      },
    );
  }
}
