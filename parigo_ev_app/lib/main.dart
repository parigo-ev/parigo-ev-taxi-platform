import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'core/user_session.dart';
import 'package:parigo_ev_app/core/api_client.dart';
import 'package:parigo_ev_app/core/api_constants.dart';
import 'screens/onboarding_screen.dart';


void _reportCrashToAdmin(dynamic error, StackTrace? stack) {
  try {
    final session = UserSession();
    final role = session.role.isNotEmpty ? session.role : 'Unknown';
    final phone = session.phone.isNotEmpty ? session.phone : 'Unknown';
    
    // Send a fire-and-forget request to the backend
    final url = Uri.parse('${ApiConstants.baseUrl}/admin/report-crash');
    
    ApiClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role,
        'phone': phone,
        'errorMessage': error.toString(),
        'stackTrace': stack?.toString(),
      }),
    ).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('Error', 500));
  } catch (e) {
    // Ignore internal reporting errors
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Pass all uncaught "fatal" errors from the framework to Crashlytics and Admin
  FlutterError.onError = (FlutterErrorDetails details) {
    _reportCrashToAdmin(details.exception, details.stack);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportCrashToAdmin(error, stack);
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ParigoEVApp());
}

class ParigoEVApp extends StatelessWidget {
  const ParigoEVApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parigo EV',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
      routes: {
        '/': (context) => const OnboardingScreen(),
      },
    );
  }
}
