import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import '../widgets/create_coupon_sheet.dart';
import 'package:parigo_ev_app/core/api_client.dart';

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  List<dynamic> _coupons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/admin/coupons'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _coupons = data['coupons'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load coupons');
      }
    } catch (e) {
      debugPrint('Error fetching coupons: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load coupons: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleCouponStatus(int couponId, bool isActive) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/coupons/toggle-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'couponId': couponId,
          'isActive': isActive,
        }),
      );

      if (response.statusCode == 200) {
        // Find coupon locally and update status
        setState(() {
          final coupon = _coupons.firstWhere((c) => c['id'] == couponId);
          coupon['is_active'] = isActive;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Coupon ${isActive ? "activated" : "deactivated"} successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      debugPrint('Error toggling coupon status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openCreateCouponSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateCouponSheet(
        onCouponCreated: _fetchCoupons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Coupon Management', style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.onSurface),
            onPressed: _fetchCoupons,
            tooltip: 'Refresh Coupons',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateCouponSheet,
        backgroundColor: AppTheme.primaryContainer,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Coupon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryContainer))
            : _coupons.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_offer_outlined, size: 64, color: AppTheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        const Text(
                          'No coupons created yet.',
                          style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openCreateCouponSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('Generate Coupon'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _coupons.length,
                    itemBuilder: (context, index) {
                      final coupon = _coupons[index];
                      final int id = coupon['id'];
                      final String code = coupon['code'] ?? '';
                      final String discountType = coupon['discount_type'] ?? 'PERCENTAGE';
                      final double discountValue = double.tryParse(coupon['discount_value']?.toString() ?? '0') ?? 0.0;
                      final String targetType = coupon['target_type'] ?? 'ALL';
                      final String? targetPhone = coupon['target_phone'];
                      final bool isActive = coupon['is_active'] ?? true;
                      
                      DateTime? validityDate;
                      if (coupon['validity_date'] != null) {
                        validityDate = DateTime.tryParse(coupon['validity_date']);
                      }

                      final bool isExpired = validityDate != null && validityDate.isBefore(DateTime.now());
                      
                      String discountText = discountType == 'PERCENTAGE' 
                          ? '${discountValue.toStringAsFixed(0)}% Off' 
                          : '₹${discountValue.toStringAsFixed(0)} Flat Off';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isActive && !isExpired)
                                        ? AppTheme.primaryContainer.withOpacity(0.2)
                                        : AppTheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.local_offer,
                                    color: (isActive && !isExpired) ? AppTheme.primaryContainer : AppTheme.onSurfaceVariant,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            code,
                                            style: GoogleFonts.nunito(
                                              color: AppTheme.onSurface,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          Switch(
                                            value: isActive,
                                            activeColor: AppTheme.primaryContainer,
                                            onChanged: (value) => _toggleCouponStatus(id, value),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        discountText,
                                        style: const TextStyle(
                                          color: AppTheme.primaryContainer,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Text(
                                            'Target: ',
                                            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
                                          ),
                                          Text(
                                            targetType == 'ALL' ? 'All Customers' : 'Individual ($targetPhone)',
                                            style: const TextStyle(color: AppTheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      if (validityDate != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Text(
                                              'Expires: ',
                                              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
                                            ),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(validityDate),
                                              style: TextStyle(
                                                color: isExpired ? Colors.redAccent : AppTheme.onSurface,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isExpired) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'EXPIRED',
                                                  style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
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
    );
  }
}
