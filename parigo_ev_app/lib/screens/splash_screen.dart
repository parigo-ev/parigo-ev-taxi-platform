import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'customer_main_screen.dart';
import 'driver_live_photo_screen.dart';
import 'admin_dashboard_screen.dart';
import '../core/user_session.dart';
import '../widgets/parigo_logo.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/permission_disclosure_dialog.dart';
import '../services/push_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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

    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Start minimum splash duration timer
    final minSplashDuration = Future.delayed(const Duration(seconds: 3));

    // Load local session concurrently
    await UserSession().loadSession();
    await PushNotificationService().syncTokenForCurrentUser();

    // iOS requires explicit authorization before it can show local alerts.
    // Android keeps the same flow for Android 13 and later.
    await Permission.notification.request();

    // Wait for the minimum splash time to pass before navigating
    await minSplashDuration;

    if (!mounted) return;

    // iOS opens the Phone app through a tel: URL and has no equivalent phone
    // permission. Requesting Permission.phone there leaves users in a prompt
    // loop, so keep this Android-only.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final phonePermissionStatus = await Permission.phone.status;
      if (!phonePermissionStatus.isGranted) {
        final accepted = await PermissionDisclosureDialog.show(
          context,
          title: 'Phone & Calls Access',
          message:
              'Parigo EV needs access to manage phone calls so you can securely contact drivers or customers directly from the app during active rides.',
          icon: Icons.phone,
        );
        if (accepted == true) {
          await Permission.phone.request();
        }
      }
    }

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
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) PushNotificationService().handleInitialNotificationTap();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
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
                    const SizedBox(height: 24),
                    ParigoLogo(
                      textStyle:
                          Theme.of(context).textTheme.displayLarge?.copyWith(
                                letterSpacing: 4,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Electrify your journey.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            letterSpacing: 2,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
