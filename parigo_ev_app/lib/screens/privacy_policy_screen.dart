import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Privacy Matters', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              'At Parigo EV, your privacy is a top priority. As a growing startup, '
              'building trust with our users is the foundation of our business.\n\n'
              '1. Information We Collect\n'
              'We collect your mobile number for authentication and your location data '
              'to provide ride and dispatch services. Without location data, the core '
              'functionality of our app would not work.\n\n'
              '2. How We Use Your Data\n'
              'Your data is solely used to connect you with drivers/passengers, estimate fares, '
              'and improve our algorithms. We do not sell your personal data to third parties.\n\n'
              '3. Data Security\n'
              'We use industry-standard security measures, including Firebase Authentication, '
              'to protect your information. As an agile startup, we regularly update our systems '
              'to patch vulnerabilities.\n\n'
              '4. Your Rights\n'
              'You have the right to request deletion of your account and associated data. '
              'Simply reach out to our support team.\n\n'
              'We value your trust and are committed to protecting your privacy as we build '
              'the future of sustainable transport.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
