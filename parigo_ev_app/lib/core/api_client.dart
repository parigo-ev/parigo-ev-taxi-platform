import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'user_session.dart';

/// A global navigator key so ApiClient can navigate to login on auth failure.
/// Must be set on MaterialApp: navigatorKey: ApiClient.navigatorKey
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class ApiClient {
  static Future<Map<String, String>> _getHeaders({Map<String, String>? customHeaders, bool forceRefresh = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Force refresh ensures we always get a valid token, never an expired cached one
        final token = await user.getIdToken(forceRefresh);
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        // Token refresh failed — log but allow the request to proceed
        // Backend will return 401 and we'll handle it below
        print('ApiClient: Token refresh failed: $e');
      }
    }
    return headers;
  }

  /// Core request method with automatic 401 retry
  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(Map<String, String> headers) makeRequest,
  ) async {
    // First attempt with potentially cached token
    final headers = await _getHeaders();
    final response = await makeRequest(headers);

    // If 401, force-refresh the token and retry once
    if (response.statusCode == 401) {
      print('ApiClient: Got 401, force-refreshing token and retrying...');
      final freshHeaders = await _getHeaders(forceRefresh: true);
      final retryResponse = await makeRequest(freshHeaders);

      // If still 401 after fresh token, the session is truly invalid
      if (retryResponse.statusCode == 401) {
        print('ApiClient: Still 401 after token refresh. Clearing session.');
        await _handleAuthFailure();
      }
      return retryResponse;
    }

    return response;
  }

  /// Clear session and redirect to login screen
  static Future<void> _handleAuthFailure() async {
    await UserSession().clear();
    await FirebaseAuth.instance.signOut();
    
    // Navigate to onboarding/login if navigator key is available
    if (appNavigatorKey.currentState != null) {
      appNavigatorKey.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return _requestWithRetry((authHeaders) {
      if (headers != null) authHeaders.addAll(headers);
      return http.get(url, headers: authHeaders);
    });
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    return _requestWithRetry((authHeaders) {
      if (headers != null) authHeaders.addAll(headers);
      return http.post(url, headers: authHeaders, body: body);
    });
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    return _requestWithRetry((authHeaders) {
      if (headers != null) authHeaders.addAll(headers);
      return http.put(url, headers: authHeaders, body: body);
    });
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) async {
    return _requestWithRetry((authHeaders) {
      if (headers != null) authHeaders.addAll(headers);
      return http.delete(url, headers: authHeaders, body: body);
    });
  }
}
