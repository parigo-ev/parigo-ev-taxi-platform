import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import 'driver_ride_execution_screen.dart' as driver_exec;
import 'package:parigo_ev_app/core/api_client.dart';


class DriverHomeTab extends StatefulWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggleOnline;
  const DriverHomeTab({
    super.key,
    required this.isOnline,
    required this.onToggleOnline,
  });

  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab> {
  double _batteryLevel = 85.0; // Default mock battery level

  List<dynamic> _assignedRides = [];
  bool _isLoadingQueue = true;

  @override
  void initState() {
    super.initState();
    _fetchAssignedRides();
  }

  Future<void> _fetchAssignedRides() async {
    try {
      final uid = UserSession().uid;
      if (uid == null) return;

      final response = await ApiClient.get(Uri.parse(
          '${ApiConstants.baseUrl}/driver/rides/assigned?driverId=$uid'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _assignedRides = data['rides'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching assigned rides: $e');
    } finally {
      setState(() {
        _isLoadingQueue = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Status Toggle
          Text('CURRENT STATUS',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppTheme.primary, letterSpacing: 2)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              widget.onToggleOnline(!widget.isOnline);
            },
            child: Container(
              width: 200,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Stack(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 24.0),
                      child: Text('OFF',
                          style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2)),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: widget.isOnline
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 120,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: widget.isOnline
                              ? [AppTheme.primaryContainer, AppTheme.primary]
                              : [
                                  AppTheme.surfaceContainerHigh,
                                  AppTheme.surfaceContainer
                                ],
                        ),
                        boxShadow: widget.isOnline
                            ? [
                                BoxShadow(
                                    color: AppTheme.primaryContainer
                                        .withOpacity(0.6),
                                    blurRadius: 25)
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          widget.isOnline ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                              color: widget.isOnline
                                  ? AppTheme.onPrimaryContainer
                                  : AppTheme.onSurface,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.isOnline ? 'Receiving ride requests' : 'You are offline',
              style: const TextStyle(color: AppTheme.onSurfaceVariant)),

          // 2. EV Battery Sync Panel
          const SizedBox(height: 32),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.battery_charging_full,
                              color: Colors.greenAccent, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text('EV BATTERY STATUS',
                                style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${_batteryLevel.toInt()}%',
                        style: GoogleFonts.nunito(
                            color: AppTheme.onSurface, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _batteryLevel,
                  min: 0,
                  max: 100,
                  activeColor: _batteryLevel > 20
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  inactiveColor: AppTheme.surfaceContainerHighest,
                  onChanged: (val) {
                    setState(() {
                      _batteryLevel = val;
                    });
                  },
                ),
                const Center(
                  child: Text(
                    'Sync battery level with Dispatch',
                    style: TextStyle(
                        color: AppTheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // 3. Stats Bento Grid
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: AppTheme.primary, size: 18),
                          SizedBox(width: 8),
                          Text('TODAY',
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('₹',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: AppTheme.primary)),
                          Text('142',
                              style: Theme.of(context).textTheme.displayLarge),
                          const Text('.50',
                              style: TextStyle(
                                  color: AppTheme.onSurfaceVariant,
                                  fontSize: 16)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule,
                              color: AppTheme.secondary, size: 18),
                          SizedBox(width: 8),
                          Text('ONLINE',
                              style: TextStyle(
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('4',
                              style: Theme.of(context).textTheme.displayLarge),
                          const Text('h',
                              style: TextStyle(
                                  color: AppTheme.onSurfaceVariant,
                                  fontSize: 16)),
                          const SizedBox(width: 4),
                          Text('15',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const Text('m',
                              style: TextStyle(
                                  color: AppTheme.onSurfaceVariant,
                                  fontSize: 16)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 4. Assigned Queue
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Assigned Queue',
                  style: Theme.of(context).textTheme.headlineMedium),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('${_assignedRides.length} Rides',
                    style: const TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingQueue)
            const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryContainer))
          else if (_assignedRides.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No rides assigned currently',
                        style: TextStyle(color: AppTheme.onSurfaceVariant))))
          else
            ..._assignedRides.map((ride) => _buildRideCard(ride)).toList(),
        ],
      ),
    );
  }

  Widget _buildRideCard(dynamic ride) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  driver_exec.DriverRideExecutionScreen(rideData: ride)),
        ).then((_) {
          // Refresh list when coming back
          _fetchAssignedRides();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border:
              const Border(left: BorderSide(color: AppTheme.primary, width: 4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEXT PICKUP',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    color: AppTheme.primary,
                                    letterSpacing: 1.5)),
                        Text('${ride['exactTime'] ?? ride['scheduledTime'] ?? 'ASAP'}',
                            style: Theme.of(context).textTheme.headlineMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.electric_car,
                            color: AppTheme.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Standard EV',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
              const Divider(color: AppTheme.outline, height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.primary, width: 4))),
                      Container(
                          width: 2,
                          height: 40,
                          color: AppTheme.primary.withOpacity(0.5)),
                      Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.onSurfaceVariant, width: 4))),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pickup Location',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text('${ride['distanceKm'] ?? '--'} km away',
                            style: const TextStyle(
                                color: AppTheme.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.lock,
                                color: AppTheme.onSurfaceVariant, size: 14),
                            SizedBox(width: 6),
                            Text('Destination hidden',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
