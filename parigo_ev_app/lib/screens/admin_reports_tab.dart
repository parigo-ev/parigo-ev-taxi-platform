import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import '../widgets/glass_card.dart';
import 'admin_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({Key? key}) : super(key: key);

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  List<dynamic> _reportsList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/admin/tickets'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _reportsList = data['tickets'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load reports')));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _resolveTicket(int ticketId) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/tickets/resolve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ticketId': ticketId}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket resolved successfully'), backgroundColor: Colors.green));
        }
        _fetchReports(); // Refresh the list
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to resolve ticket'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
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
          onPressed: () => AdminDashboardScreen.of(context)?.openDrawer(),
        ),
        title: const Text(
          'Customer Reports',
          style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _reportsList.isEmpty
              ? const Center(
                  child: Text('No reports available', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16)),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _fetchReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reportsList.length,
                    itemBuilder: (context, index) {
                      final item = _reportsList[index];
                      final date = item['created_at'] != null
                          ? DateFormat('MMM d, y h:mm a').format(DateTime.parse(item['created_at']))
                          : 'Unknown Date';

                      final isResolved = item['status'] == 'RESOLVED';

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
                                      'Issue: ${item['issue_type'] ?? 'Unknown'}',
                                      style: const TextStyle(
                                          color: AppTheme.primaryContainer,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isResolved ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isResolved ? Colors.green : Colors.red),
                                    ),
                                    child: Text(
                                      isResolved ? 'RESOLVED' : 'OPEN',
                                      style: TextStyle(
                                        color: isResolved ? Colors.green : Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customer: ${item['customer_name'] ?? 'Unknown'} (${item['customer_phone'] ?? 'N/A'})',
                                style: const TextStyle(
                                    color: AppTheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              if (item['ride_id'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Ride ID: ${item['ride_id']}',
                                    style: const TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12),
                                  ),
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
                                  item['description'] ?? 'No description provided.',
                                  style: const TextStyle(color: AppTheme.onSurface),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 12),
                                  ),
                                  if (!isResolved)
                                    ElevatedButton(
                                      onPressed: () => _resolveTicket(item['id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryContainer,
                                        foregroundColor: AppTheme.onPrimaryContainer,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Mark as Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
