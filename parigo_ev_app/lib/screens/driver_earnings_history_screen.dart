import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';

class DriverEarningsHistoryScreen extends StatefulWidget {
  const DriverEarningsHistoryScreen({super.key});

  @override
  State<DriverEarningsHistoryScreen> createState() => _DriverEarningsHistoryScreenState();
}

class _DriverEarningsHistoryScreenState extends State<DriverEarningsHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String _totalBalance = '0.00';
  int _ridesToday = 0;
  List<dynamic> _recentTrips = [];

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: AppTheme.onPrimary,
              onSurface: AppTheme.onSurface,
              surface: AppTheme.surfaceContainer,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchEarnings();
    }
  }

  Future<void> _fetchEarnings() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final response = await ApiClient.get(
        Uri.parse('\${ApiConstants.baseUrl}/driver/earnings?driverId=\$uid&date=\$dateStr'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalBalance = data['total_balance'].toString();
          _ridesToday = data['rides_today'] ?? 0;
          _recentTrips = data['recent_trips'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching earnings history: \$e');
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
        title: Text('Earnings History', style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppTheme.primary),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryContainer))
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Selector Banner
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy').format(_selectedDate),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.onSurface),
                            ),
                            const Icon(Icons.edit_calendar, color: AppTheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Balance Card
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Earnings for Day', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16)),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('₹', style: GoogleFonts.nunito(color: AppTheme.primaryContainer, fontSize: 32)),
                                Text(_totalBalance.split('.')[0], style: GoogleFonts.nunito(color: AppTheme.onSurface, fontSize: 48)),
                                if (_totalBalance.contains('.'))
                                  Text('.${_totalBalance.split('.')[1]}', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 24)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      
                      // Summary Stats
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Completed Rides', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                                const SizedBox(height: 8),
                                Text('\$_ridesToday', style: Theme.of(context).textTheme.headlineMedium),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Transactions List
                      const Text(
                        'RIDES',
                        style: TextStyle(
                          color: AppTheme.primaryFixed,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_recentTrips.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No rides on this date.', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                        )
                      else
                        ..._recentTrips.map((tx) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GlassCard(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.directions_car, color: AppTheme.primaryContainer),
                                ),
                                title: Text(tx['title'] ?? 'Ride Payment',
                                    style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold)),
                                subtitle: Text(tx['time'] ?? '',
                                    style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                                trailing: Text(
                                  '\${tx['amount']}',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
