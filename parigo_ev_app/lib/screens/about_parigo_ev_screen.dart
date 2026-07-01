import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/parigo_logo.dart';
import 'dart:ui';

class AboutParigoEvScreen extends StatelessWidget {
  const AboutParigoEvScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Glassy App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.surface.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.onSurface.withOpacity(0.2), width: 1.5),
                              ),
                              child: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'About Parigo EV',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        // Logo Display
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                              decoration: BoxDecoration(
                                color: AppTheme.surface.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppTheme.onSurface.withOpacity(0.2), width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24)
                                ],
                              ),
                              child: ParigoLogo(
                                textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Version 1.0.0 (Beta)',
                          style: TextStyle(
                            color: AppTheme.onSurfaceVariant.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Mission Card
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.electric_car, color: AppTheme.primaryContainer, size: 28),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Our Mission',
                                    style: GoogleFonts.nunito(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Parigo EV is born out of a passion to revolutionize urban mobility. We are here to electrify the streets of Indore and beyond. Our mission is simple: provide a premium, zero-emission transportation experience that is incredibly seamless and aggressively modern. No compromises on luxury, zero compromises on the planet.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.onSurfaceVariant,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Why Parigo Card
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.flash_on, color: Colors.amber, size: 28),
                                  const SizedBox(width: 12),
                                  Text(
                                    'The Parigo Edge',
                                    style: GoogleFonts.nunito(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildEdgeItem(Icons.energy_savings_leaf, '100% Electric Fleet', 'Silent, smooth, and sustainable rides.'),
                              const SizedBox(height: 12),
                              _buildEdgeItem(Icons.diamond, 'Premium Standard', 'Handpicked drivers and impeccably maintained vehicles.'),
                              const SizedBox(height: 12),
                              _buildEdgeItem(Icons.groups, 'Built for Indorians', 'A hyper-local startup that understands the pulse of the city.'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                        
                        // Footer
                        const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          'Proudly built in Indore, India.',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryContainer, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
