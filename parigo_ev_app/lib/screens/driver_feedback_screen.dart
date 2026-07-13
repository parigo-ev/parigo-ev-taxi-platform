import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import 'package:parigo_ev_app/core/api_client.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DriverFeedbackScreen extends StatefulWidget {
  final String driverId;
  const DriverFeedbackScreen({super.key, required this.driverId});

  @override
  State<DriverFeedbackScreen> createState() => _DriverFeedbackScreenState();
}

class _DriverFeedbackScreenState extends State<DriverFeedbackScreen> {
  List<dynamic> _feedbackList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/driver/feedback/${widget.driverId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _feedbackList = data['feedback'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.customerFeedback, style: GoogleFonts.audiowide(color: AppTheme.onSurface)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _feedbackList.isEmpty
              ? Center(child: Text('No feedback yet.', style: TextStyle(color: AppTheme.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _feedbackList.length,
                  itemBuilder: (context, index) {
                    final fb = _feedbackList[index];
                    final date = fb['created_at'] != null 
                        ? DateFormat('MMM d, y').format(DateTime.parse(fb['created_at']))
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(fb['customer_name'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface, fontSize: 16)),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${fb['customer_rating']}', style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (fb['customer_feedback'] != null && fb['customer_feedback'].toString().isNotEmpty)
                              Text('"${fb['customer_feedback']}"', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(date, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
