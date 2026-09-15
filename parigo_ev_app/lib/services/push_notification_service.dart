import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import '../screens/notifications_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();

  factory PushNotificationService() => _instance;

  static const _channelId = 'parigo_notifications';
  static const _channelName = 'Parigo EV notifications';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  RemoteMessage? _initialMessage;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    await _configureLocalNotifications();
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_openNotificationInbox);
    _initialMessage = await _messaging.getInitialMessage();

    _messaging.onTokenRefresh.listen((token) {
      _registerToken(token);
    });
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) => _openNotificationInbox(null),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Ride, wallet, and account updates from Parigo EV.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Ride, wallet, and account updates from Parigo EV.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final id = int.tryParse(message.data['notificationId'] ?? '') ??
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    await _localNotifications.show(
      id,
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> syncTokenForCurrentUser() async {
    if (kIsWeb || UserSession().uid.isEmpty) return;
    try {
      final token =
          await _messaging.getToken().timeout(const Duration(seconds: 5));
      if (token != null) await _registerToken(token);
    } catch (error) {
      debugPrint('Unable to obtain an FCM token: $error');
    }
  }

  Future<void> unregisterTokenForCurrentUser() async {
    if (kIsWeb || UserSession().uid.isEmpty) return;

    try {
      final token =
          await _messaging.getToken().timeout(const Duration(seconds: 5));
      if (token == null) return;

      await ApiClient.delete(
        Uri.parse('${ApiConstants.baseUrl}/user/notifications/device-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Unable to unregister FCM token: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    if (UserSession().uid.isEmpty || kIsWeb) return;

    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/user/notifications/device-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'platform': platform}),
      );
    } catch (error) {
      debugPrint('Unable to register FCM token: $error');
    }
  }

  void handleInitialNotificationTap() {
    final message = _initialMessage;
    _initialMessage = null;
    if (message != null && UserSession().uid.isNotEmpty) {
      _openNotificationInbox(message);
    }
  }

  void _openNotificationInbox(RemoteMessage? message) {
    if (UserSession().uid.isEmpty) {
      _initialMessage = message;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator
          .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    });
  }
}
