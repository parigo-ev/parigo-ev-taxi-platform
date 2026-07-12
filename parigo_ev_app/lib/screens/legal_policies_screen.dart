import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LegalPoliciesScreen extends StatelessWidget {
  const LegalPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Legal & Policies',
              style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
          iconTheme: const IconThemeData(color: AppTheme.onSurface),
          bottom: const TabBar(
            labelColor: AppTheme.primaryContainer,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            indicatorColor: AppTheme.primaryContainer,
            isScrollable: true,
            tabs: [
              Tab(text: 'Terms & Conditions'),
              Tab(text: 'Privacy Policy'),
              Tab(text: 'Refund Policy'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PolicyView(policyType: PolicyType.terms),
            _PolicyView(policyType: PolicyType.privacy),
            _PolicyView(policyType: PolicyType.refund),
          ],
        ),
      ),
    );
  }
}

enum PolicyType { terms, privacy, refund }

class _PolicyView extends StatelessWidget {
  final PolicyType policyType;
  const _PolicyView({required this.policyType});

  @override
  Widget build(BuildContext context) {
    String title = '';
    String content = '';

    switch (policyType) {
      case PolicyType.terms:
        title = 'Terms and Conditions';
        content = '''
Last Updated: July 2026

1. Acceptance of Terms
By accessing and using the Parigo EV application ("App"), you agree to be bound by these Terms and Conditions. If you do not agree, please do not use our services.

2. Description of Service
Parigo EV provides a technology platform connecting users seeking transportation with independent drivers operating electric vehicles (EVs).

3. User Responsibilities
- You must provide accurate information when registering.
- You are responsible for all activity under your account.
- You agree to treat drivers and vehicles with respect. Damage to vehicles may result in cleaning/repair fees charged to your account.

4. Payments and Billing
All payments must be made through the App via Parigo Wallet, UPI, or supported Cards. Fares are calculated based on base rates, distance, and time. Tolls and taxes may be added to the final fare.

5. Limitation of Liability
Parigo EV acts as an intermediary. We are not liable for direct, indirect, or consequential damages arising from the use of our transportation services.
''';
        break;
      case PolicyType.privacy:
        title = 'Privacy Policy';
        content = '''
Last Updated: July 2026

1. Information We Collect
We collect information you provide directly to us (name, phone, email) and data collected automatically (location data, device information, usage metrics).

2. How We Use Your Information
- To provide, maintain, and improve our services.
- To process payments and send receipts.
- To track rides in real-time for safety and navigation.
- To send promotional communications (if opted in).

3. Sharing of Information
We share your pickup/dropoff locations and first name with your assigned driver. We do not sell your personal data to third parties. We may share data with law enforcement if required by law.

4. Data Security
We implement industry-standard encryption to protect your data. Payment information is securely handled by our payment gateways (Razorpay/PhonePe) and is not stored on our servers.

5. Your Rights
You may request account deletion or a copy of your data by contacting support.
''';
        break;
      case PolicyType.refund:
        title = 'Cancellation & Refund Policy';
        content = '''
Last Updated: July 2026

1. Cancellation by Customer
- You may cancel a ride without any penalty before a driver is assigned.
- If you cancel a ride more than 5 minutes after a driver has been assigned and is en route, a Cancellation Fee may apply.
- Scheduled rides cancelled within 30 minutes of the pickup time will incur a cancellation fee.

2. Cancellation by Driver or System
If a driver cancels your ride or the system is unable to fulfill your request, you will not be charged, and any prepaid amount will be refunded immediately.

3. Refund Process
- Refunds for cancelled trips or disputed fares are processed immediately to your Parigo Wallet.
- If you request a refund to your original payment method (Bank/Card), it may take 3-5 business days to reflect in your account depending on your bank.

4. Disputing a Fare
If you believe you were overcharged, or if there was an issue with the ride (e.g., driver took a significantly longer route), you can raise a ticket via the "Report an Issue" section within 24 hours of the ride completion.
''';
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.primaryContainer, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text(content, style: const TextStyle(color: AppTheme.onSurface, fontSize: 16, height: 1.6)),
        ],
      ),
    );
  }
}
