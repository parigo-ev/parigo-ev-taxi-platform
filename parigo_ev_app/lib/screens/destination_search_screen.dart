import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../core/api_keys.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class DestinationSearchScreen extends StatefulWidget {
  final String title;
  final String hintText;
  final double? currentLat;
  final double? currentLng;

  const DestinationSearchScreen({
    Key? key,
    this.title = 'Search Destination',
    this.hintText = 'Where to?',
    this.currentLat,
    this.currentLng,
  }) : super(key: key);

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placeList = [];

  void _getSuggestion(String input) async {
    if (input.isEmpty) {
      setState(() {
        _placeList = [];
      });
      return;
    }

    // URL encode the input to handle spaces
    final encodedInput = Uri.encodeComponent(input);

    // Build the query
    String request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedInput&key=${ApiKeys.googleMapsKey}';
    
    // Add location bias if current location is available (50km radius)
    if (widget.currentLat != null && widget.currentLng != null) {
      request += '&location=${widget.currentLat},${widget.currentLng}&radius=50000&strictbounds=true';
    } else {
      // Optional: Add a general country restriction if no location is available
      request += '&components=country:in';
    }

    try {
      var response = await ApiClient.get(Uri.parse(request));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'REQUEST_DENIED' ||
            data['status'] == 'INVALID_REQUEST') {
          print('Google Maps API Error: ${data['error_message']}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Maps API Error: ${data['status']}')));
          }
        } else {
          setState(() {
            _placeList = data['predictions'] ?? [];
          });
        }
      } else {
        throw Exception('Failed to load predictions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _getPlaceDetails(String placeId, String description) async {
    String request =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=${ApiKeys.googleMapsKey}';

    try {
      var response = await ApiClient.get(Uri.parse(request));
      if (response.statusCode == 200) {
        var result = jsonDecode(response.body)['result'];
        if (result != null && result['geometry'] != null) {
          var location = result['geometry']['location'];
          Navigator.pop(context, {
            'description': description,
            'lat': location['lat'],
            'lng': location['lng'],
          });
        }
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(color: AppTheme.onSurface)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppTheme.primaryContainer.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryContainer.withOpacity(0.1),
                        blurRadius: 15)
                  ]),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.primaryContainer.withOpacity(0.5),
                              blurRadius: 10)
                        ]),
                    child: const Icon(Icons.location_on,
                        color: AppTheme.onPrimaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _getSuggestion,
                      autofocus: true,
                      style: const TextStyle(color: AppTheme.onSurface),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.hintText,
                        hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppTheme.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        _getSuggestion('');
                      },
                    )
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _placeList.length,
              itemBuilder: (context, index) {
                var prediction = _placeList[index];
                return ListTile(
                  leading:
                      const Icon(Icons.location_city, color: AppTheme.primary),
                  title: Text(prediction['structured_formatting']['main_text'],
                      style: const TextStyle(color: AppTheme.onSurface)),
                  subtitle: Text(
                      prediction['structured_formatting']['secondary_text'] ??
                          '',
                      style: const TextStyle(color: AppTheme.onSurfaceVariant)),
                  onTap: () {
                    _getPlaceDetails(
                        prediction['place_id'], prediction['description']);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
