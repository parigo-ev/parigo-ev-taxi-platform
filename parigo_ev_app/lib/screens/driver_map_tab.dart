import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

class DriverMapTab extends StatefulWidget {
  const DriverMapTab({super.key});

  @override
  State<DriverMapTab> createState() => _DriverMapTabState();
}

class _DriverMapTabState extends State<DriverMapTab> {
  GoogleMapController? _mapController;
  final LatLng _driverLocation =
      const LatLng(22.7196, 75.8577); // Default to Indore

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _driverLocation, zoom: 14),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
          onMapCreated: (controller) => _mapController = controller,
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outline),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]),
            child: const Row(
              children: [
                Icon(Icons.gps_fixed, color: AppTheme.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Free Roam Mode. Waiting for dispatch assignments...',
                    style: TextStyle(color: AppTheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
