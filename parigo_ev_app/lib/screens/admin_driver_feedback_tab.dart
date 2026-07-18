import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import '../widgets/glass_card.dart';
import 'admin_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AdminDriverFeedbackTab extends StatefulWidget {
  const AdminDriverFeedbackTab({Key? key}) : super(key: key);

  @override
  State<AdminDriverFeedbackTab> createState() => _AdminDriverFeedbackTabState();
}

class _AdminDriverFeedbackTabState extends State<AdminDriverFeedbackTab> {
  List<dynamic> _feedbackList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/admin/feedback'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _feedbackList = data['feedback'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load feedback')));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
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
          onPressed: () => AdminDashboardScreen.of(context)?.openDrawer(),
        ),
        title: const Text(
          'Driver Feedback',
          style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _fetchFeedback,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _feedbackList.isEmpty
              ? const Center(
                  child: Text('No feedback available', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16)),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _fetchFeedback,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _feedbackList.length,
                    itemBuilder: (context, index) {
                      final item = _feedbackList[index];
                      final date = item['created_at'] != null
                          ? DateFormat('MMM d, y h:mm a').format(DateTime.parse(item['created_at']))
                          : 'Unknown Date';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Driver: ${item['driver_name']}',
                                      style: const TextStyle(
                                          color: AppTheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _buildStars(item['driver_rating'] ?? 0),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customer: ${item['customer_name']}',
                                style: const TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.outline.withOpacity(0.5)),
                                ),
                                child: Text(
                                  item['driver_feedback']?.isNotEmpty == true
                                      ? item['driver_feedback']
                                      : 'No written feedback provided.',
                                  style: TextStyle(
                                      color: item['driver_feedback']?.isNotEmpty == true
                                          ? AppTheme.onSurface
                                          : AppTheme.onSurfaceVariant,
                                      fontStyle: item['driver_feedback']?.isNotEmpty == true
                                          ? FontStyle.normal
                                          : FontStyle.italic),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
