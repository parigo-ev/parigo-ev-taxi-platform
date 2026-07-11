import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import '../widgets/add_driver_sheet.dart';
import 'admin_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AdminFleetTab extends StatefulWidget {
  const AdminFleetTab({super.key});

  @override
  State<AdminFleetTab> createState() => _AdminFleetTabState();
}

class _AdminFleetTabState extends State<AdminFleetTab> {
  List<dynamic> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFleet();
  }

  Future<void> _fetchFleet() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get(
            Uri.parse('${ApiConstants.baseUrl}/admin/fleet'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _drivers = data['fleet'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load fleet');
      }
    } catch (e) {
      print('Error fetching fleet: $e');
      setState(() => _isLoading = false);
    }
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
        title: Text('Fleet & Battery',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.primaryContainer),
            tooltip: 'Add New Driver',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddDriverSheet(
                  onDriverAdded: _fetchFleet,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _fetchFleet,
          )
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryContainer))
            : _drivers.isEmpty
                ? const Center(
                    child: Text(
                      'No drivers in the fleet.',
                      style: TextStyle(
                          color: AppTheme.onSurfaceVariant, fontSize: 16),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchFleet,
                    color: AppTheme.primaryContainer,
                    backgroundColor: AppTheme.surfaceContainer,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _drivers.length,
                      itemBuilder: (context, index) {
                        final driver = _drivers[index];
                        final int battery = driver['battery'] ?? 100;

                        Color batteryColor = Colors.green;
                        if (battery <= 20) {
                          batteryColor = Colors.red;
                        } else if (battery <= 50) {
                          batteryColor = Colors.orange;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            driver['profile_picture_url'] !=
                                                    null
                                                ? CircleAvatar(
                                                    backgroundImage:
                                                        NetworkImage(driver[
                                                            'profile_picture_url']))
                                                : const CircleAvatar(
                                                    backgroundColor: AppTheme
                                                        .surfaceContainerHighest,
                                                    child: Icon(Icons.person,
                                                        color: AppTheme
                                                            .onSurfaceVariant),
                                                  ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      driver['name'] ??
                                                          'Unknown',
                                                      style: const TextStyle(
                                                          color: AppTheme
                                                              .onSurface,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                  Text(
                                                      driver['id']
                                                              ?.toString() ??
                                                          '',
                                                      style: const TextStyle(
                                                          color: AppTheme
                                                              .onSurfaceVariant,
                                                          fontSize: 12),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: driver['status'] == 'ONLINE'
                                              ? Colors.green.withOpacity(0.2)
                                              : driver['status'] == 'IN_RIDE'
                                                  ? Colors.orange
                                                      .withOpacity(0.2)
                                                  : Colors.red.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          driver['status'] ?? 'OFFLINE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: driver['status'] == 'ONLINE'
                                                ? Colors.greenAccent
                                                : driver['status'] == 'IN_RIDE'
                                                    ? Colors.orangeAccent
                                                    : Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                      color: AppTheme.outline, height: 32),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Vehicle',
                                              style: TextStyle(
                                                  color:
                                                      AppTheme.onSurfaceVariant,
                                                  fontSize: 12)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.electric_car,
                                                  color:
                                                      AppTheme.primaryContainer,
                                                  size: 16),
                                              const SizedBox(width: 6),
                                              Text(driver['vehicle'] ?? 'EV',
                                                  style: const TextStyle(
                                                      color: AppTheme.onSurface,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text('Est. Range',
                                              style: TextStyle(
                                                  color:
                                                      AppTheme.onSurfaceVariant,
                                                  fontSize: 12)),
                                          const SizedBox(height: 4),
                                          Text(driver['range'] ?? 'N/A',
                                              style: const TextStyle(
                                                  color: AppTheme.onSurface,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Icon(
                                        battery <= 20
                                            ? Icons.battery_alert
                                            : Icons.battery_charging_full,
                                        color: batteryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text('Battery Level',
                                                    style: TextStyle(
                                                        color: AppTheme
                                                            .onSurfaceVariant,
                                                        fontSize: 12)),
                                                Text('$battery%',
                                                    style: TextStyle(
                                                        color: batteryColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            LinearProgressIndicator(
                                              value: battery / 100,
                                              backgroundColor: AppTheme
                                                  .surfaceContainerHighest,
                                              color: batteryColor,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              minHeight: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (battery <= 20) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  Colors.red.withOpacity(0.3))),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning,
                                              color: Colors.redAccent,
                                              size: 16),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  'CRITICAL: Route driver to charging station immediately.',
                                                  style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 12))),
                                        ],
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
