import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import '../screens/wallet_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class PreBookingPaymentSheet extends StatefulWidget {
  final double baseFare;
  final Function(
    String paymentMethod, 
    bool isPrepaid, {
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? razorpayOrderId,
  }) onPaymentConfirmed;

  const PreBookingPaymentSheet({
    super.key, 
    required this.baseFare,
    required this.onPaymentConfirmed,
  });

  @override
  State<PreBookingPaymentSheet> createState() => _PreBookingPaymentSheetState();
}

class _PreBookingPaymentSheetState extends State<PreBookingPaymentSheet> {
  String _selectedMethod = 'WALLET'; // 'WALLET', 'UPI', 'PAY_LATER'
  String _selectedUpiApp = 'RAZORPAY'; // 'RAZORPAY', 'PHONEPE'
  bool _isProcessing = false;
  
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpayPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handleRazorpayPaymentSuccess(PaymentSuccessResponse response) {
    Navigator.pop(context); // Close sheet
    widget.onPaymentConfirmed(
      'RAZORPAY',
      true,
      razorpayPaymentId: response.paymentId,
      razorpaySignature: response.signature,
      razorpayOrderId: response.orderId,
    );
  }

  void _handleRazorpayPaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Failed: ${response.message}')),
      );
    }
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External Wallet: ${response.walletName}')),
      );
    }
  }

  Future<void> _fetchWalletBalance() async {
    final phone = UserSession().phone;
    if (phone.isEmpty) {
      if (mounted) setState(() => _isLoadingWallet = false);
      return;
    }
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/wallet/balance/$phone'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _walletBalance = (data['balance'] ?? 0).toDouble();
            _isLoadingWallet = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingWallet = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  double get _walletFare {
    return widget.baseFare * 0.95; // 5% discount
  }

  void _confirmSelection() {
    if (_selectedMethod == 'WALLET') {
      if (_walletBalance < _walletFare) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insufficient Wallet Balance. Redirecting to top up...')));
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WalletScreen()),
        ).then((_) {
          _fetchWalletBalance();
        });
        return;
      }

      Navigator.pop(context);
      widget.onPaymentConfirmed('WALLET', true);
      return;
    }

    if (_selectedMethod == 'PAY_LATER') {
      Navigator.pop(context);
      widget.onPaymentConfirmed('CASH', false);
      return;
    }

    if (_selectedMethod == 'UPI' && _selectedUpiApp == 'RAZORPAY') {
      _startRazorpayFlow();
      return;
    }

    String finalMethod = _selectedMethod == 'UPI' ? _selectedUpiApp : _selectedMethod;
    Navigator.pop(context);
    widget.onPaymentConfirmed(finalMethod, _selectedMethod != 'PAY_LATER');
  }

  Future<void> _startRazorpayFlow() async {
    final phone = UserSession().phone;
    final cleanPhone = phone.replaceAll('+91', '').trim().isEmpty ? '1234567890' : phone.replaceAll('+91', '').trim();

    setState(() => _isProcessing = true);

    try {
      final body = jsonEncode({'amount': widget.baseFare});
      final res = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/wallet/create-order'),
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final orderId = data['order']['id'];

        var options = {
          'key': 'rzp_live_T4ez8Jy477DN1A',
          'amount': (widget.baseFare * 100).toInt(),
          'name': 'Parigo EV',
          'description': 'Pre-book Ride Payment',
          'order_id': orderId,
          'prefill': {
            'contact': cleanPhone,
            'email': 'customer@parigo.com'
          },
          'theme': {
            'color': '#3366FF'
          }
        };

        _razorpay.open(options);
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initialize Razorpay')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error initializing payment')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseFareStr = '₹${widget.baseFare.toStringAsFixed(2)}';
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
              Text('Payment Method', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
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
                            const Text('Pre-book with Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
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
                        child: Text('Pre-book with UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
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

          // Pay Later Option
          GestureDetector(
            onTap: () => setState(() => _selectedMethod = 'PAY_LATER'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selectedMethod == 'PAY_LATER' ? AppTheme.primary : Colors.transparent, width: 2),
              ),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                children: [
                  const Icon(Icons.money, color: Colors.green, size: 30),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Pay after the ride (Cash/Online)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
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
              text: _isProcessing ? 'PROCESSING...' : 'CONFIRM PAYMENT & BOOK',
              onPressed: _isProcessing ? () {} : () => _confirmSelection(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
