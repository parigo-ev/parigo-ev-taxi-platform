import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/parigo_logo.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  void _selectRole(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -200,
            left: -100,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.width * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceContainerHigh.withOpacity(0.6),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryContainer.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.0,
              height: MediaQuery.of(context).size.width * 1.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withOpacity(0.4),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar / Theme Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ParigoLogo(
                        textStyle: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose\nYour Path',
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select how you want to experience the electric future.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Role Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      _buildRoleCard(
                        context: context,
                        title: 'Customer',
                        subtitle: 'Find chargers & juice up.',
                        icon: Icons.electric_car,
                        onTap: () => _selectRole(context, 'Customer'),
                      ),
                      const SizedBox(height: 16),
                      _buildRoleCard(
                        context: context,
                        title: 'Driver',
                        subtitle: 'Manage rides & earnings.',
                        icon: Icons.local_taxi,
                        onTap: () => _selectRole(context, 'Driver'),
                      ),
                      const SizedBox(height: 16),
                      _buildRoleCard(
                        context: context,
                        title: 'Admin',
                        subtitle: 'System & station control.',
                        icon: Icons.admin_panel_settings,
                        onTap: () => _selectRole(context, 'Admin'),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Icon(icon, size: 32, color: AppTheme.primary),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.primary, size: 32),
          ],
        ),
      ),
    );
  }
}
