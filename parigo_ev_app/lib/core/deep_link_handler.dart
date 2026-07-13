import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DeepLinkHandler {
  // Singleton pattern
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // This holds the currently pending destination from a deep link.
  // It has a map with { 'lat': double, 'lng': double, 'description': String }
  final ValueNotifier<Map<String, dynamic>?> pendingDestination = ValueNotifier(null);

  void initAppLinks() async {
    _appLinks = AppLinks();

    // Handle incoming app links while app is open
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _processUri(uri);
      }
    }, onError: (err) {
      if (kDebugMode) {
        print("DeepLinkHandler Error: $err");
      }
    });

    // Handle initial app link when app was completely closed
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _processUri(initialUri);
      }
    } catch (e) {
      if (kDebugMode) {
        print("DeepLinkHandler Initial Link Error: $e");
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  /// Mark the pending destination as handled so it doesn't get consumed again
  void clearPendingDestination() {
    pendingDestination.value = null;
  }

  Future<void> _processUri(Uri uri) async {
    if (kDebugMode) {
      print("DeepLinkHandler: Received URI: $uri");
    }

    try {
      // Step 1: If it's a shortened URL (like maps.app.goo.gl or goo.gl/maps), resolve it first.
      String urlString = uri.toString();
      if (uri.host == 'maps.app.goo.gl' || uri.host == 'goo.gl') {
        urlString = await _resolveShortUrl(uri);
      }

      // Step 2: Parse the long URL to extract latitude and longitude
      final destination = _extractCoordinates(urlString);

      if (destination != null) {
        pendingDestination.value = destination;
      }
    } catch (e) {
      if (kDebugMode) {
        print("DeepLinkHandler Error processing URI: $e");
      }
    }
  }

  Future<String> _resolveShortUrl(Uri uri) async {
    try {
      // Make a GET request. 
      // Dart's http client automatically follows redirects by default.
      // After following all redirects, the response will have the final URL.
      final client = http.Client();
      final request = http.Request('GET', uri)
        ..followRedirects = false; 
        
      // Some shorteners use a series of 301/302 redirects.
      // We will follow them manually to find the maps.google.com link.
      String currentUrl = uri.toString();
      int redirects = 0;
      
      while (redirects < 5) {
        final res = await client.send(http.Request('HEAD', Uri.parse(currentUrl))..followRedirects = false);
        if (res.statusCode >= 300 && res.statusCode < 400) {
          final location = res.headers['location'];
          if (location != null) {
            currentUrl = location;
            redirects++;
          } else {
            break;
          }
        } else {
          break;
        }
      }
      client.close();
      return currentUrl;
    } catch (e) {
      if (kDebugMode) {
        print("DeepLinkHandler Error resolving short URL: $e");
      }
      return uri.toString();
    }
  }

  Map<String, dynamic>? _extractCoordinates(String url) {
    // We look for patterns in the URL:
    // 1. @latitude,longitude (from google.com/maps/place/.../@lat,lng)
    // 2. search/latitude,longitude
    // 3. ?q=latitude,longitude

    final latLngRegex = RegExp(r'(?:@|q=|\/search\/|\/place\/.*\@)(-?\d+\.\d+),(-?\d+\.\d+)');
    final match = latLngRegex.firstMatch(url);

    if (match != null && match.groupCount >= 2) {
      final latString = match.group(1);
      final lngString = match.group(2);
      if (latString != null && lngString != null) {
        final lat = double.tryParse(latString);
        final lng = double.tryParse(lngString);
        if (lat != null && lng != null) {
          return {
            'lat': lat,
            'lng': lng,
            'description': 'Shared Location',
          };
        }
      }
    }

    // Alternative: parse 'll=lat,lng'
    final uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.containsKey('ll')) {
       final parts = uri.queryParameters['ll']!.split(',');
       if (parts.length == 2) {
         final lat = double.tryParse(parts[0]);
         final lng = double.tryParse(parts[1]);
         if (lat != null && lng != null) {
          return {
            'lat': lat,
            'lng': lng,
            'description': 'Shared Location',
          };
        }
       }
    }

    return null;
  }
}
