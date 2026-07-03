import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import '../screens/feedback_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class PaymentSelectionBottomSheet extends StatefulWidget {
  final dynamic rideData;

  const PaymentSelectionBottomSheet({super.key, required this.rideData});

  @override
  State<PaymentSelectionBottomSheet> createState() => _PaymentSelectionBottomSheetState();
}

class _PaymentSelectionBottomSheetState extends State<PaymentSelectionBottomSheet> {
  String _selectedMethod = 'WALLET'; // 'WALLET', 'UPI', 'CASH'
  String _selectedUpiApp = 'RAZORPAY'; // 'RAZORPAY', 'PHONEPE'
  bool _isProcessing = false;
  
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/wallet/$uid'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _walletBalance = (data['balance'] ?? 0).toDouble();
            _isLoadingWallet = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  double get _baseFare {
    return double.tryParse(widget.rideData['finalFare']?.toString() ?? widget.rideData['estimatedFare']?.toString() ?? '0') ?? 0.0;
  }

  double get _walletFare {
    return _baseFare * 0.95; // 5% discount
  }

  Future<void> _processPayment() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    if (_selectedMethod == 'WALLET') {
      if (_walletBalance < _walletFare) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insufficient Wallet Balance. Please Top Up.')));
        // Navigate to Wallet Screen or show topup UI
        return;
      }
    }

    setState(() => _isProcessing = true);

    String finalPaymentMethod = _selectedMethod;
    if (_selectedMethod == 'UPI') {
      finalPaymentMethod = _selectedUpiApp;
    }

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/ride/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rideId': widget.rideData['id'],
          'uid': uid,
          'paymentMethod': finalPaymentMethod,
          'fare': _selectedMethod == 'WALLET' ? _walletFare : _baseFare
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context); // Close sheet
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackScreen(
              role: 'Customer',
              rideId: widget.rideData['id']?.toString() ?? 'unknown',
              otherPartyName: widget.rideData['driverDetails']?['name'] ?? 'Driver',
            ),
          ),
        );
      } else {
        String errorMsg = 'Payment failed';
        try {
          final errData = jsonDecode(response.body);
          if (errData['error'] != null) {
            errorMsg = errData['error'];
            if (errData['details'] != null) {
              errorMsg += ': ${errData['details']}';
            }
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        String cleanMessage = e.toString();
        if (cleanMessage.startsWith('Exception: ')) {
          cleanMessage = cleanMessage.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $cleanMessage')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseFareStr = '₹${_baseFare.toStringAsFixed(2)}';
    final walletFareStr = '₹${_walletFare.toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Complete Payment', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
              Text(baseFareStr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Wallet Option
          GestureDetector(
            onTap: () => setState(() => _selectedMethod = 'WALLET'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selectedMethod == 'WALLET' ? AppTheme.primary : Colors.transparent, width: 2),
              ),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppTheme.primaryContainer, size: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Parigo Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                              child: const Text('5% OFF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        _isLoadingWallet 
                            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('Balance: ₹${_walletBalance.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                  Text(walletFareStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ],
              ),
            ),
            ),
          ),
          
          const SizedBox(height: 12),

          // UPI Option
          GestureDetector(
            onTap: () => setState(() => _selectedMethod = 'UPI'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selectedMethod == 'UPI' ? AppTheme.primary : Colors.transparent, width: 2),
              ),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: Colors.orange, size: 30),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text('Pay with UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
                      ),
                      Text(baseFareStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  if (_selectedMethod == 'UPI') ...[
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.outline),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ChoiceChip(
                          label: const Text('Razorpay'),
                          selected: _selectedUpiApp == 'RAZORPAY',
                          onSelected: (val) => setState(() => _selectedUpiApp = 'RAZORPAY'),
                          selectedColor: AppTheme.primaryContainer.withOpacity(0.2),
                        ),
                        ChoiceChip(
                          label: const Text('PhonePe'),
                          selected: _selectedUpiApp == 'PHONEPE',
                          onSelected: (val) => setState(() => _selectedUpiApp = 'PHONEPE'),
                          selectedColor: AppTheme.primaryContainer.withOpacity(0.2),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
            ),
          ),

          const SizedBox(height: 12),

          // Cash Option
          GestureDetector(
            onTap: () => setState(() => _selectedMethod = 'CASH'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selectedMethod == 'CASH' ? AppTheme.primary : Colors.transparent, width: 2),
              ),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                children: [
                  const Icon(Icons.money, color: Colors.green, size: 30),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Pay with Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
                  ),
                  Text(baseFareStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            ),
          ),

          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: _isProcessing ? 'Processing...' : 'CONFIRM PAYMENT',
              onPressed: _isProcessing ? () {} : () => _processPayment(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
