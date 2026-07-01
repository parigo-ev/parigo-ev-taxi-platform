import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  static Future<Map<String, String>> _getHeaders({Map<String, String>? customHeaders}) async {
    final headers = {'Content-Type': 'application/json'};
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Force refresh if needed, but default is fine
        final token = await user.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        // Silently let it fail, backend will return 401
      }
    }
    return headers;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final authHeaders = await _getHeaders(customHeaders: headers);
    return await http.get(url, headers: authHeaders);
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final authHeaders = await _getHeaders(customHeaders: headers);
    return await http.post(url, headers: authHeaders, body: body);
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final authHeaders = await _getHeaders(customHeaders: headers);
    return await http.put(url, headers: authHeaders, body: body);
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) async {
    final authHeaders = await _getHeaders(customHeaders: headers);
    return await http.delete(url, headers: authHeaders, body: body);
  }
}
