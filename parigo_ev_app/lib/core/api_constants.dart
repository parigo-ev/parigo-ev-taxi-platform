import 'dart:io';

class ApiConstants {
  // Update this to your computer's local Wi-Fi IP address for testing on physical devices without USB.
  static String get baseUrl {
    if (Platform.isAndroid) {
      // 192.168.1.10 is the current local IP of the PC running the backend
      return 'http://192.168.1.10:3000/api';
    }
    return 'http://127.0.0.1:3000/api';
  }
}
