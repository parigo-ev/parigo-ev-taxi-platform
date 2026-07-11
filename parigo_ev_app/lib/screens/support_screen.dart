import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Help & Support',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Frequently Asked Questions',
                  style: GoogleFonts.nunito(
                      color: AppTheme.onSurface, fontSize: 20)),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    _buildFAQItem(
                      'How do I cancel my ride?',
                      'You can cancel your ride from the tracking screen before the driver arrives. Note that cancellation fees may apply if cancelled after 5 minutes.',
                    ),
                    const Divider(
                        color: AppTheme.surfaceContainerHighest, height: 1),
                    _buildFAQItem(
                      'What payment methods are accepted?',
                      'We accept all major credit/debit cards, UPI, and Parigo EV Wallet balance.',
                    ),
                    const Divider(
                        color: AppTheme.surfaceContainerHighest, height: 1),
                    _buildFAQItem(
                      'Are the EVs sanitized?',
                      'Yes! All our fleet vehicles are sanitized before and after every ride for your safety.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text('Need more help?',
                  style: GoogleFonts.nunito(
                      color: AppTheme.onSurface, fontSize: 20)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: AppTheme.onPrimaryContainer),
                      label: const Text('Live Chat',
                          style: TextStyle(
                              color: AppTheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Starting live chat...')));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side:
                            const BorderSide(color: AppTheme.primaryContainer),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.phone_in_talk,
                          color: AppTheme.primaryContainer),
                      label: const Text('Call Us',
                          style: TextStyle(
                              color: AppTheme.primaryContainer,
                              fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Calling support...')));
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question,
          style: const TextStyle(
              color: AppTheme.onSurface, fontWeight: FontWeight.bold)),
      iconColor: AppTheme.primaryContainer,
      collapsedIconColor: AppTheme.onSurfaceVariant,
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      children: [
        Text(answer,
            style:
                const TextStyle(color: AppTheme.onSurfaceVariant, height: 1.5)),
      ],
    );
  }
}
