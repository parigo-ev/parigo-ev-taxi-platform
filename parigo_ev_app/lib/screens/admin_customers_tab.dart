import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import 'package:intl/intl.dart';
import 'admin_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AdminCustomersTab extends StatefulWidget {
  const AdminCustomersTab({super.key});

  @override
  State<AdminCustomersTab> createState() => _AdminCustomersTabState();
}

class _AdminCustomersTabState extends State<AdminCustomersTab> {
  List<dynamic> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  List<dynamic> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/admin/customers'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _customers = data['customers'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      print('Error fetching customers: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown Date';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    } catch (e) {
      return 'Invalid Date';
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
        title: Text('Registered Customers',
            style: GoogleFonts.nunito(color: AppTheme.primaryContainer)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _fetchCustomers,
          )
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryContainer))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Customers',
                                    style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 14)),
                                SizedBox(height: 4),
                                Text('Platform Growth',
                                    style: TextStyle(
                                        color: AppTheme.primaryContainer,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                              '${_customers.length}',
                              style: GoogleFonts.nunito(
                                color: AppTheme.onSurface,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      style: const TextStyle(color: AppTheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search by customer name...',
                        hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.primaryContainer),
                        filled: true,
                        fillColor: AppTheme.surfaceContainerHigh,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _filteredCustomers.isEmpty
                        ? const Center(
                            child: Text(
                              'No customers found.',
                              style: TextStyle(
                                  color: AppTheme.onSurfaceVariant,
                                  fontSize: 16),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchCustomers,
                            color: AppTheme.primaryContainer,
                            backgroundColor: AppTheme.surfaceContainer,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              itemCount: _filteredCustomers.length,
                              itemBuilder: (context, index) {
                                final customer = _filteredCustomers[index];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: GlassCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: AppTheme
                                                .primaryContainer
                                                .withOpacity(0.1),
                                            child: Text(
                                              (customer['name'] ?? 'U')[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color:
                                                    AppTheme.primaryContainer,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    customer['name'] ??
                                                        'Unknown Name',
                                                    style: const TextStyle(
                                                        color:
                                                            AppTheme.onSurface,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.phone,
                                                        size: 14,
                                                        color: AppTheme
                                                            .onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                        customer['phone'] ??
                                                            'N/A',
                                                        style: const TextStyle(
                                                            color: AppTheme
                                                                .onSurfaceVariant,
                                                            fontSize: 12)),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.email,
                                                        size: 14,
                                                        color: AppTheme
                                                            .onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                          customer['email'] ??
                                                              'No Email',
                                                          style: const TextStyle(
                                                              color: AppTheme
                                                                  .onSurfaceVariant,
                                                              fontSize: 12),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                    'Joined: ${_formatDate(customer['created_at'])}',
                                                    style: const TextStyle(
                                                        color: AppTheme
                                                            .primaryContainer,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
