class ApiConstants {
  // Production URL — Railway (always available, never changes)
  static String get baseUrl {
    return 'https://parigo-ev-backend-production.up.railway.app/api';
  }

  // Uncomment below and comment above for local development only:
  // static String get baseUrl {
  //   if (Platform.isAndroid) {
  //     return 'http://YOUR_LOCAL_IP:3000/api';
  //   }
  //   return 'http://127.0.0.1:3000/api';
  // }
}
