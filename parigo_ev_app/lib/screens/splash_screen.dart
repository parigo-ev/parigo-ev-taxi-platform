import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'customer_main_screen.dart';
import 'driver_live_photo_screen.dart';
import 'admin_dashboard_screen.dart';
import '../core/user_session.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/parigo_logo.dart';
import '../widgets/parigo_icon_i.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _textFadeOutAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _zoomAnimation = Tween<double>(begin: 1.0, end: 60.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: Curves.easeInOutQuart,
      ),
    );

    _textFadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Start minimum splash duration timer
    final minSplashDuration = Future.delayed(const Duration(seconds: 3));
    
    // Load local session concurrently
    await UserSession().loadSession();

    // Wait for the minimum splash time to pass
    await minSplashDuration;

    if (!mounted) return;

    // Run the zoom transition animation before navigating!
    await _zoomController.forward();

    if (!mounted) return;

    Widget nextScreen = const OnboardingScreen();

    // Determine next screen based on saved session
    if (UserSession().uid.isNotEmpty && UserSession().role.isNotEmpty) {
      final roleLower = UserSession().role.toLowerCase();
      if (roleLower == 'admin') {
        nextScreen = const AdminDashboardScreen();
      } else if (roleLower == 'driver') {
        nextScreen = DriverLivePhotoScreen(driverId: UserSession().uid);
      } else {
        nextScreen = const CustomerMainScreen();
      }
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _zoomController.dispose();
    super.dispose();
  }

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
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withOpacity(0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.0,
              height: MediaQuery.of(context).size.width * 1.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryContainer.withOpacity(0.2),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedBuilder(
                  animation: _zoomController,
                  builder: (context, child) {
                    final textStyle = Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(
                          letterSpacing: 4,
                          color: AppTheme.primary,
                        );
                    final style = GoogleFonts.audiowide(textStyle: textStyle);
                    final fontSize = style.fontSize ?? 48.0;
                    final iconSize = fontSize;
                    final iconWidth = iconSize * 1.25;
                    final spacing = fontSize * 0.12;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top circle with bolt icon (fades out)
                        Opacity(
                          opacity: _textFadeOutAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.bolt,
                                size: 80, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Logo Stack
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Text parts fade out
                            Opacity(
                              opacity: _textFadeOutAnimation.value,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'PAR',
                                    style: style.copyWith(
                                      foreground: Paint()
                                        ..shader = const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(Rect.fromLTWH(0.0, 0.0, fontSize * 6, fontSize)),
                                    ),
                                  ),
                                  SizedBox(width: iconWidth + spacing * 2),
                                  Text(
                                    'GO EV',
                                    style: style.copyWith(
                                      foreground: Paint()
                                        ..shader = const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(Rect.fromLTWH(0.0, 0.0, fontSize * 6, fontSize)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Zooming custom "I" icon
                            Transform.scale(
                              scale: _zoomAnimation.value,
                              child: const ParigoIconI(
                                size: 48.0,
                                colors: [
                                  Color(0xFF10B981), // Emerald Green
                                  Color(0xFF059669), // Dark Emerald
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Subtitle fades out
                        Opacity(
                          opacity: _textFadeOutAnimation.value,
                          child: Text(
                            'Electrify your journey.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                  letterSpacing: 2,
                                ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

