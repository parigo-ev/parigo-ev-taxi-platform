import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:convert';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import 'report_issue_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  final bool isAdmin;

  const RideDetailsScreen({super.key, required this.ride, this.isAdmin = false});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  Map<String, dynamic>? _parseLocation(dynamic locData) {
    if (locData == null) return null;
    if (locData is Map) return Map<String, dynamic>.from(locData);
    if (locData is String) {
      try {
        final map = jsonDecode(locData);
        if (map is Map) return Map<String, dynamic>.from(map);
      } catch (_) {
        return {'address': locData};
      }
    }
    return null;
  }

  Map<String, dynamic>? get _pickup => _parseLocation(widget.ride['pickupLocation'] ?? widget.ride['pickup']);
  Map<String, dynamic>? get _dropoff => _parseLocation(widget.ride['dropoffLocation'] ?? widget.ride['destination']);

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  void _setupMap() {
    final p = _pickup;
    final d = _dropoff;

    if (p != null && p['lat'] != null && d != null && d['lat'] != null) {
      final pickupLat = double.tryParse(p['lat'].toString());
      final pickupLng = double.tryParse(p['lng'].toString());
      final dropoffLat = double.tryParse(d['lat'].toString());
      final dropoffLng = double.tryParse(d['lng'].toString());

      if (pickupLat != null && pickupLng != null && dropoffLat != null && dropoffLng != null) {
        final pickupLatLng = LatLng(pickupLat, pickupLng);
        final dropoffLatLng = LatLng(dropoffLat, dropoffLng);

        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ));

        _markers.add(Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoffLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Dropoff'),
        ));

        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: [pickupLatLng, dropoffLatLng],
          color: AppTheme.primary,
          width: 4,
        ));
      }
    }
  }

  Future<void> _generateInvoice() async {
    final pdf = pw.Document();
    
    // Fallbacks
    final dateStr = widget.ride['createdAt'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(widget.ride['createdAt'])) : 'N/A';
    final amount = double.tryParse(widget.ride['fare']?.toString() ?? '0') ?? 0.0;
    final gst = double.tryParse(widget.ride['gstAmount']?.toString() ?? '0') ?? (amount * 0.05); // Estimate 5% if missing
    final base = double.tryParse(widget.ride['baseFare']?.toString() ?? '0') ?? (amount - gst);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PARIGO EV', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                pw.SizedBox(height: 8),
                pw.Text('Electrify your journey.', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                pw.SizedBox(height: 40),
                
                pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Ride ID: ${widget.ride['id']}'),
                        pw.Text('Date: $dateStr'),
                        pw.Text('Payment Method: ${widget.ride['paymentMethod'] ?? 'CASH'}'),
                        if (widget.ride['transactionId'] != null)
                          pw.Text('Transaction ID: ${widget.ride['transactionId']}'),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer: ${widget.ride['customerDetails']?['name'] ?? 'Guest'}'),
                        pw.Text('Driver: ${widget.ride['driverDetails']?['name'] ?? 'Unknown'}'),
                      ]
                    ),
                  ]
                ),
                pw.SizedBox(height: 40),
                
                // Route
                pw.Text('Route Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Pickup: ${_pickup?['address'] ?? 'Unknown'}'),
                pw.Text('Dropoff: ${_dropoff?['address'] ?? 'Unknown'}'),
                pw.SizedBox(height: 20),
                
                // Fare Table
                pw.TableHelper.fromTextArray(
                  data: <List<String>>[
                    <String>['Description', 'Amount (INR)'],
                    <String>['Base Fare & Distance', base.toStringAsFixed(2)],
                    <String>['GST (5%)', gst.toStringAsFixed(2)],
                    <String>['Total Fare', amount.toStringAsFixed(2)],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                  cellAlignment: pw.Alignment.centerRight,
                  cellAlignments: {0: pw.Alignment.centerLeft},
                ),
                
                pw.Spacer(),
                pw.Center(child: pw.Text('Thank you for riding with Parigo EV. You saved CO2 today!')),
              ]
            )
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${widget.ride['id']}.pdf',
    );
  }

  void _launchPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pickup;
    final d = _dropoff;
    
    LatLng? initialPos;
    if (p != null && p['lat'] != null && p['lng'] != null) {
      final lat = double.tryParse(p['lat'].toString());
      final lng = double.tryParse(p['lng'].toString());
      if (lat != null && lng != null) {
        initialPos = LatLng(lat, lng);
      } else {
        initialPos = const LatLng(20.5937, 78.9629); // Center of India fallback
      }
    } else {
      initialPos = const LatLng(20.5937, 78.9629); // Center of India fallback
    }

    final double distance = double.tryParse(widget.ride['distanceKm']?.toString() ?? '0') ?? 0.0;
    final double co2Saved = distance * 0.15; // Rough estimate: 150g CO2 per km saved vs petrol

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Ride Details', style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Map View
              SizedBox(
                height: 200,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: initialPos, zoom: 12),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quick Stats & Eco Impact
                    if (distance > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.eco, color: Colors.green, size: 24),
                            const SizedBox(width: 8),
                            Text('You saved ${co2Saved.toStringAsFixed(2)} kg of CO2!', 
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Route details
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.my_location, color: Colors.green, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(p?['address'] ?? 'Unknown Pickup', style: const TextStyle(color: AppTheme.onSurface))),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 9.0, top: 4, bottom: 4),
                              child: Container(width: 2, height: 20, color: AppTheme.surfaceContainerHighest),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(d?['address'] ?? 'Unknown Dropoff', style: const TextStyle(color: AppTheme.onSurface))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Participants (Admin sees both, Customer sees driver)
                    Text('Participants', style: GoogleFonts.nunito(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (widget.isAdmin) ...[
                      _buildParticipantRow('Customer', widget.ride['customerDetails']?['name'] ?? 'Unknown', widget.ride['customerDetails']?['phone']),
                      const Divider(color: AppTheme.surfaceContainerHighest),
                    ],
                    _buildParticipantRow('Driver', widget.ride['driverDetails']?['name'] ?? 'Unknown', widget.ride['driverDetails']?['phone'], vehicle: widget.ride['driverDetails']?['vehicle_type']),

                    const SizedBox(height: 24),

                    // Timeline
                    Text('Timeline', style: GoogleFonts.nunito(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTimelineRow('Booked At', _formatDate(widget.ride['scheduledTime'])),
                            const Divider(color: AppTheme.surfaceContainerHighest),
                            _buildTimelineRow('Picked Up', _formatDate(widget.ride['rideStartTime'])),
                            const Divider(color: AppTheme.surfaceContainerHighest),
                            _buildTimelineRow('Dropped Off', _formatDate(widget.ride['createdAt'])),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Billing
                    Text('Billing & Payment', style: GoogleFonts.nunito(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTimelineRow('Total Fare', '₹${widget.ride['fare']}'),
                            const Divider(color: AppTheme.surfaceContainerHighest),
                            _buildTimelineRow('Payment Mode', widget.ride['paymentMethod'] ?? 'N/A'),
                            if (widget.ride['transactionId'] != null) ...[
                              const Divider(color: AppTheme.surfaceContainerHighest),
                              _buildTimelineRow('Transaction ID', widget.ride['transactionId']),
                            ],
                            const Divider(color: AppTheme.surfaceContainerHighest),
                            _buildTimelineRow('Ride ID', widget.ride['id'] ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    PrimaryButton(
                      text: 'Download Invoice',
                      icon: Icons.download,
                      onPressed: _generateInvoice,
                    ),
                    const SizedBox(height: 16),
                    
                    if (!widget.isAdmin) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppTheme.primaryContainer),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.help_outline, color: AppTheme.primaryContainer),
                        label: const Text('Need Help with this Ride?', style: TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ReportIssueScreen(preSelectedRideId: widget.ride['id'])));
                        },
                      ),
                    ]
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRow(String role, String name, String? phone, {String? vehicle}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryContainer.withOpacity(0.2),
        child: Icon(role == 'Driver' ? Icons.drive_eta : Icons.person, color: AppTheme.primaryContainer),
      ),
      title: Text(name, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phone != null) Text(phone, style: const TextStyle(color: AppTheme.onSurfaceVariant)),
          if (vehicle != null) Text('Vehicle: $vehicle', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
      trailing: widget.isAdmin || role == 'Driver' 
        ? IconButton(
            icon: const Icon(Icons.phone, color: AppTheme.primaryContainer),
            onPressed: () => _launchPhone(phone),
          )
        : null,
    );
  }

  Widget _buildTimelineRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
