import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Razorpay _razorpay;
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String _selectedGateway = 'razorpay';

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchWalletData();
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  String get _phoneNumber {
    return FirebaseAuth.instance.currentUser?.phoneNumber?.replaceAll('+91', '') ?? '1234567890';
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    try {
      final balanceRes = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/wallet/balance/$_phoneNumber'));
      final transRes = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/wallet/transactions/$_phoneNumber'));
      
      if (balanceRes.statusCode == 200 && transRes.statusCode == 200) {
        setState(() {
          _balance = jsonDecode(balanceRes.body)['balance'].toDouble();
          _transactions = jsonDecode(transRes.body)['transactions'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching wallet data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final body = jsonEncode({
        'phone': _phoneNumber,
        'amount': _currentTopupAmount,
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      });

      final res = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/wallet/verify-payment'),
        body: body,
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('₹$_currentTopupAmount added to wallet successfully!')),
          );
        }
        _fetchWalletData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment verification failed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error verifying payment.')),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Failed: ${response.message}')),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External Wallet Selected: ${response.walletName}')),
      );
    }
  }

  double _currentTopupAmount = 0.0;

  void _startAddMoneyFlow() {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainer,
              title: const Text('Add Money', style: TextStyle(color: AppTheme.onSurface)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Enter amount (₹)',
                      hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Payment Method', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                  ),
                  RadioListTile<String>(
                    title: const Text('Razorpay', style: TextStyle(color: AppTheme.onSurface)),
                    value: 'razorpay',
                    groupValue: _selectedGateway,
                    activeColor: AppTheme.primaryFixed,
                    onChanged: (val) => setStateDialog(() => _selectedGateway = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text('PhonePe', style: TextStyle(color: AppTheme.onSurface)),
                    value: 'phonepe',
                    groupValue: _selectedGateway,
                    activeColor: AppTheme.primaryFixed,
                    onChanged: (val) => setStateDialog(() => _selectedGateway = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    _currentTopupAmount = amount;
                    
                    if (_selectedGateway == 'razorpay') {
                      _startRazorpayFlow(amount);
                    } else {
                      _startPhonePeFlow(amount);
                    }
                  },
                  child: const Text('Proceed'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _startRazorpayFlow(double amount) async {
    try {
      final body = jsonEncode({'amount': amount});
      final res = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/wallet/create-order'),
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final orderId = data['order']['id'];

        var options = {
          'key': 'rzp_live_T4ez8Jy477DN1A',
          'amount': (amount * 100).toInt(),
          'name': 'Parigo EV',
          'description': 'Wallet Top-up',
          'order_id': orderId,
          'prefill': {
            'contact': _phoneNumber,
            'email': 'customer@parigo.com'
          },
          'theme': {
            'color': '#3366FF'
          }
        };

        _razorpay.open(options);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initialize Razorpay')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error initializing payment')),
        );
      }
    }
  }

  Future<void> _startPhonePeFlow(double amount) async {
    try {
      final body = jsonEncode({'amount': amount, 'phone': _phoneNumber});
      final res = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/wallet/phonepe/create-order'),
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final url = data['url'];
        final merchantTransactionId = data['merchantTransactionId'];

        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          
          if (mounted) {
            _showPhonePeVerificationDialog(merchantTransactionId, amount);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch PhonePe')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to initialize PhonePe')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
      }
    }
  }

  void _showPhonePeVerificationDialog(String merchantTransactionId, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceContainer,
          title: const Text('Verify Payment', style: TextStyle(color: AppTheme.onSurface)),
          content: const Text('Did you complete the payment?', style: TextStyle(color: AppTheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
              ),
              onPressed: () async {
                Navigator.pop(context);
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryFixed)),
                );

                try {
                  final body = jsonEncode({
                    'merchantTransactionId': merchantTransactionId,
                    'phone': _phoneNumber,
                    'amount': amount,
                  });

                  final res = await ApiClient.post(
                    Uri.parse('${ApiConstants.baseUrl}/wallet/phonepe/verify'),
                    body: body,
                  );
                  
                  if (mounted) Navigator.pop(context); // hide loading

                  if (res.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('₹$amount added to wallet successfully!')),
                    );
                    _fetchWalletData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment not successful or pending.')),
                    );
                  }
                } catch (e) {
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error verifying payment.')),
                  );
                }
              },
              child: const Text('Yes, Verify'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Wallet', style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryFixed))
        : SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Card
                GlassCard(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryContainer.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '₹${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 32),
                        PrimaryButton(
                          text: 'Add Money',
                          icon: Icons.add,
                          onPressed: _startAddMoneyFlow,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Transactions List
                const Text(
                  'RECENT TRANSACTIONS',
                  style: TextStyle(
                    color: AppTheme.primaryFixed,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                if (_transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No transactions yet.', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                  )
                else
                  ..._transactions.map((tx) {
                    final isDebit = tx['type'] == 'DEBIT';
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
                            child: Icon(
                              isDebit ? Icons.directions_car : Icons.account_balance_wallet,
                              color: isDebit ? AppTheme.onSurfaceVariant : AppTheme.primaryContainer,
                            ),
                          ),
                          title: Text(tx['description'] ?? (isDebit ? 'Ride Payment' : 'Wallet Top-up'),
                              style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${tx['id'] ?? ''}',
                              style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                          trailing: Text(
                            '${isDebit ? '-' : '+'}₹${double.parse(tx['amount'].toString()).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isDebit ? AppTheme.onSurface : Colors.greenAccent,
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
