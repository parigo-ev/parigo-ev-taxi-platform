import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Payment Methods',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saved Cards',
                  style: GoogleFonts.nunito(
                      color: AppTheme.onSurface, fontSize: 18)),
              const SizedBox(height: 16),
              GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.credit_card,
                      color: AppTheme.primaryContainer),
                  title: const Text('**** **** **** 4242',
                      style: TextStyle(color: AppTheme.onSurface)),
                  subtitle: const Text('Expires 12/28',
                      style: TextStyle(color: AppTheme.onSurfaceVariant)),
                  trailing: const Icon(Icons.check_circle,
                      color: AppTheme.primaryContainer),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 32),
              Text('UPI Accounts',
                  style: GoogleFonts.nunito(
                      color: AppTheme.onSurface, fontSize: 18)),
              const SizedBox(height: 16),
              GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: AppTheme.primaryContainer),
                  title: const Text('jane.doe@okbank',
                      style: TextStyle(color: AppTheme.onSurface)),
                  trailing:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onTap: () {},
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon:
                      const Icon(Icons.add, color: AppTheme.onPrimaryContainer),
                  label: const Text('ADD NEW PAYMENT METHOD',
                      style: TextStyle(
                          color: AppTheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Adding payment method...')));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
