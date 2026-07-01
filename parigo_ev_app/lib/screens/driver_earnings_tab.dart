import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class DriverEarningsTab extends StatefulWidget {
  const DriverEarningsTab({super.key});

  @override
  State<DriverEarningsTab> createState() => _DriverEarningsTabState();
}

class _DriverEarningsTabState extends State<DriverEarningsTab> {
  bool _isLoading = true;
  String _totalBalance = '0.00';
  int _ridesToday = 0;
  double _hoursOnline = 0.0;
  List<dynamic> _recentTrips = [];

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await ApiClient.get(
            Uri.parse('${ApiConstants.baseUrl}/driver/earnings?driverId=$uid'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalBalance = data['total_balance'].toString();
          _ridesToday = data['rides_today'] ?? 0;
          _hoursOnline = (data['hours_online'] ?? 0).toDouble();
          _recentTrips = data['recent_trips'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching earnings: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryContainer));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EARNINGS',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppTheme.primary, letterSpacing: 2)),
          const SizedBox(height: 16),

          // 1. Total Balance Card
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: AppTheme.primaryContainer),
                    SizedBox(width: 8),
                    Text('Available Balance',
                        style: TextStyle(
                            color: AppTheme.onSurfaceVariant, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('₹',
                        style: GoogleFonts.nunito(
                            color: AppTheme.primaryContainer, fontSize: 32)),
                    Text(_totalBalance.split('.')[0],
                        style: GoogleFonts.nunito(
                            color: AppTheme.onSurface, fontSize: 48)),
                    if (_totalBalance.contains('.'))
                      Text('.${_totalBalance.split('.')[1]}',
                          style: const TextStyle(
                              color: AppTheme.onSurfaceVariant, fontSize: 24)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.primaryContainer.withOpacity(0.2),
                      foregroundColor: AppTheme.primaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                            color: AppTheme.primaryContainer, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('WITHDRAW FUNDS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 2. Summary Stats
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Rides Completed',
                          style: TextStyle(
                              color: AppTheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('$_ridesToday',
                          style: Theme.of(context).textTheme.headlineMedium),
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
                    children: [
                      const Text('Hours Online',
                          style: TextStyle(
                              color: AppTheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('$_hoursOnline',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // 3. Recent Transactions
          Text('Recent Trips',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          if (_recentTrips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No trips completed yet.',
                  style: TextStyle(color: AppTheme.onSurfaceVariant)),
            )
          else
            ..._recentTrips
                .map((trip) => _buildTransactionItem(context, trip['title'],
                    trip['amount'], trip['time'], trip['isCredit']))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, String title,
      String amount, String time, bool isCredit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCredit
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(time,
                      style: const TextStyle(
                          color: AppTheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isCredit ? Colors.greenAccent : AppTheme.onSurface,
              ),
            )
          ],
        ),
      ),
    );
  }
}
