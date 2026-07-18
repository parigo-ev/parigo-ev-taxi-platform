import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../core/api_constants.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'admin_booking_channel', // id
    'Admin Booking Service', // title
    description: 'This channel is used for background booking polling.', // description
    importance: Importance.low, // low importance so it doesn't ring continuously
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'admin_booking_channel',
      initialNotificationTitle: 'Parigo Admin Service',
      initialNotificationContent: 'Monitoring for new bookings',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final Set<String> knownRideIds = {};
  bool isFirstFetchCompleted = false;

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');

      // Only run polling if the user is an Admin
      if (role != 'Admin') {
        // We can stop the ringtone just in case they logged out while it was ringing
        FlutterRingtonePlayer().stop();
        isFirstFetchCompleted = false; 
        knownRideIds.clear();
        return;
      }

      final response = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/admin/rides/pending'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rides = data['rides'] ?? [];
        
        bool hasNewRide = false;
        
        for (var ride in rides) {
          final String id = ride['id'].toString();
          if (!knownRideIds.contains(id)) {
            knownRideIds.add(id);
            if (isFirstFetchCompleted) {
              hasNewRide = true;
            }
          }
        }
        isFirstFetchCompleted = true;

        if (hasNewRide) {
          FlutterRingtonePlayer().play(
            fromAsset: "assets/sounds/booking_alert.wav",
            looping: true,
            asAlarm: true,
            volume: 1.0,
          );
        }
      }
    } catch (e) {
      print('Background Service Polling Error: \$e');
    }
  });
}
