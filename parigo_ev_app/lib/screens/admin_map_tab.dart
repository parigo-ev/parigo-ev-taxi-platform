import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import 'admin_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AdminMapTab extends StatefulWidget {
  const AdminMapTab({super.key});

  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab> {
  final Completer<GoogleMapController> _controller = Completer();

  // New Delhi Center as default mock location
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(22.7196, 75.8577),
    zoom: 12.0,
  );

  Set<Marker> _markers = {};

  Color _darken(Color color, [double amount = .2]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _lighten(Color color, [double amount = .2]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Future<BitmapDescriptor> _getRealisticCarMarker(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double width = 56.0;
    final double height = 110.0;

    // 1. Deep Drop Shadow for 3D depth
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(6, 8, width, height), const Radius.circular(20)),
        shadowPaint);

    // 2. Base Body (Dark bevel edge)
    final Path bodyPath = Path()
      ..moveTo(12, 0)
      ..quadraticBezierTo(width / 2, -6, width - 12, 0)
      ..lineTo(width - 4, 30)
      ..lineTo(width, height - 12)
      ..quadraticBezierTo(width / 2, height + 6, 0, height - 12)
      ..lineTo(4, 30)
      ..close();

    final Paint basePaint = Paint()..color = _darken(color, 0.3);
    canvas.drawPath(bodyPath, basePaint);

    // 3. Main Body (Glossy 3D Gradient)
    final Path mainBodyPath = Path()
      ..moveTo(14, 2)
      ..quadraticBezierTo(width / 2, -2, width - 14, 2)
      ..lineTo(width - 6, 30)
      ..lineTo(width - 2, height - 14)
      ..quadraticBezierTo(width / 2, height + 2, 2, height - 14)
      ..lineTo(6, 30)
      ..close();

    final Paint bodyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width / 2, height / 2),
        height / 1.2,
        [
          _lighten(color, 0.2), // Bright center
          color, // Base color
          _darken(color, 0.2), // Dark edges
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawPath(mainBodyPath, bodyPaint);

    // 4. Side Mirrors (3D angled)
    final Paint mirrorPaint = Paint()..color = _darken(color, 0.1);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 36, 8, 12), const Radius.circular(4)),
        mirrorPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(width - 8, 36, 8, 12), const Radius.circular(4)),
        mirrorPaint);

    // 5. Windshield (Curved 3D Glass)
    final Paint windowPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 30), Offset(0, 60),
          [const Color(0xFF1E272E), const Color(0xFF0D1115)]);
    final Path windshield = Path()
      ..moveTo(12, 38)
      ..quadraticBezierTo(width / 2, 32, width - 12, 38)
      ..lineTo(width - 8, 54)
      ..quadraticBezierTo(width / 2, 58, 8, 54)
      ..close();
    canvas.drawPath(windshield, windowPaint);

    // 5b. Windshield Specular Highlight (Reflection)
    final Path reflection = Path()
      ..moveTo(16, 42)
      ..lineTo(28, 42)
      ..lineTo(20, 52)
      ..lineTo(10, 52)
      ..close();
    canvas.drawPath(reflection, Paint()..color = Colors.white.withOpacity(0.3));

    // 6. Panoramic Sunroof / Roof
    final Paint roofPaint = Paint()..color = const Color(0xFF050505);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(14, 60, width - 28, 30), const Radius.circular(6)),
        roofPaint);

    // Roof highlight
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(18, 62, 4, 26), const Radius.circular(2)),
        Paint()..color = Colors.white.withOpacity(0.15));

    // 7. Rear Window
    final Path rearWindow = Path()
      ..moveTo(14, 92)
      ..quadraticBezierTo(width / 2, 90, width - 14, 92)
      ..lineTo(width - 10, 100)
      ..quadraticBezierTo(width / 2, 104, 10, 100)
      ..close();
    canvas.drawPath(rearWindow, windowPaint);

    // 8. Glowing Headlights (3D neon effect)
    final Paint headlightGlow = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(12, 4), 6, headlightGlow);
    canvas.drawCircle(Offset(width - 12, 4), 6, headlightGlow);

    final Paint headlightPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(10, 4)
          ..lineTo(16, 2),
        headlightPaint);
    canvas.drawPath(
        Path()
          ..moveTo(width - 10, 4)
          ..lineTo(width - 16, 2),
        headlightPaint);

    // 9. Taillights (Red glowing strips)
    final Paint taillightGlow = Paint()
      ..color = Colors.redAccent.withOpacity(0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(
        Path()
          ..moveTo(8, height - 6)
          ..lineTo(20, height - 3),
        taillightGlow
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke);
    canvas.drawPath(
        Path()
          ..moveTo(width - 8, height - 6)
          ..lineTo(width - 20, height - 3),
        taillightGlow);

    final Paint taillightPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(8, height - 6)
          ..lineTo(20, height - 3),
        taillightPaint);
    canvas.drawPath(
        Path()
          ..moveTo(width - 8, height - 6)
          ..lineTo(width - 20, height - 3),
        taillightPaint);

    final ui.Image image = await pictureRecorder
        .endRecording()
        .toImage(width.toInt() + 10, height.toInt() + 10);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _loadLiveDrivers() async {
    try {
      final response = await ApiClient.get(
            Uri.parse('${ApiConstants.baseUrl}/admin/drivers/available'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> drivers = data['drivers'] ?? [];

        Set<Marker> newMarkers = {};
        for (var d in drivers) {
          if (d['lat'] == null || d['lng'] == null) continue;

          // For now, if they are returned by this endpoint, they are online.
          Color color = Colors.green;
          final icon = await _getRealisticCarMarker(color);

          newMarkers.add(Marker(
            markerId: MarkerId(d['id'].toString()),
            position: LatLng(double.parse(d['lat'].toString()),
                double.parse(d['lng'].toString())),
            infoWindow: InfoWindow(
              title: d['name'],
              snippet: 'Status: ONLINE',
            ),
            icon: icon,
          ));
        }

        if (mounted) {
          setState(() {
            _markers = newMarkers;
          });
        }
      }
    } catch (e) {
      print('Error fetching live driver locations: $e');
    }
  }

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLiveDrivers();
    _timer =
        Timer.periodic(const Duration(seconds: 10), (_) => _loadLiveDrivers());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppTheme.onSurface),
          onPressed: () {
            AdminDashboardScreen.of(context)?.openDrawer();
          },
        ),
        title: Text('Live Fleet Tracking',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType
                .normal, // Use normal map type since .dark is not an enum in google_maps_flutter
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),

          // Legend Overlay
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outline),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4))
                  ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(Colors.green, 'Online'),
                  _buildLegendItem(Colors.orange, 'In Ride'),
                  _buildLegendItem(Colors.red, 'Offline'),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
