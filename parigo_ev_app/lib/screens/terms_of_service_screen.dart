import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to Parigo EV!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              'These Terms of Service govern your use of the Parigo EV app and platform. '
              'By using our services, you agree to these terms.\n\n'
              '1. Introduction\n'
              'We are a startup dedicated to making electric vehicle transportation accessible '
              'and reliable. As a young and growing company, our services are constantly evolving, '
              'and we are thrilled to have you as part of our journey.\n\n'
              '2. User Accounts\n'
              'You must provide accurate information when creating an account. You are responsible '
              'for keeping your OTP and PIN secure. Since we are a startup, we currently rely heavily '
              'on trust and community guidelines.\n\n'
              '3. Ride and Services\n'
              'Parigo EV provides a platform to connect EV drivers with passengers. We do our best to '
              'ensure availability, but as an early-stage company, occasional disruptions may occur.\n\n'
              '4. Payment & Fares\n'
              'Fares are calculated based on time, distance, and demand. We are continuously refining '
              'our pricing models to provide fair compensation to our drivers while keeping rides affordable.\n\n'
              '5. Limitation of Liability\n'
              'We are building the future of mobility, but we are not perfect yet. We provide our platform "as is" '
              'and are not liable for indirect damages or lost profits.\n\n'
              'Thank you for supporting our startup!',
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
