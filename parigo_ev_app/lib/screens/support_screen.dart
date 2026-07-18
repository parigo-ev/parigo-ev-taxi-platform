import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'report_issue_screen.dart';
import 'legal_policies_screen.dart';
import '../core/user_session.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  final String supportPhone = '+918878587615';
  final String supportEmail = 'abhimanyusingh16111998@gmail.com';
  final String emergencyPhone = '+918878587615'; // Using the same as SOS per user request

  Future<void> _launchUrl(String urlString, BuildContext context) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch the app'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SOS EMERGENCY SECTION
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.emergency, size: 28),
                label: const Text('SOS / EMERGENCY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                onPressed: () => _launchUrl('tel:$emergencyPhone', context),
              ),
              
              const SizedBox(height: 24),
              
              // REPORT ISSUE SECTION
              GlassCard(
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportIssueScreen()));
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.report_problem_outlined, color: AppTheme.primaryContainer, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Report an Issue', style: TextStyle(color: AppTheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Submit a ticket about a ride, payment, or app bug.', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              Text('Contact Us Directly',
                  style: GoogleFonts.nunito(
                      color: AppTheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // CONTACT US BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.primaryContainer),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.phone_in_talk, color: AppTheme.primaryContainer),
                      label: const Text('Call Us', style: TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold)),
                      onPressed: () => _launchUrl('tel:$supportPhone', context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.email_outlined, color: AppTheme.onPrimaryContainer),
                      label: const Text('Email Us', style: TextStyle(color: AppTheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                      onPressed: () => _launchUrl('mailto:$supportEmail?subject=Parigo%20EV%20Customer%20Support', context),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              Text('Frequently Asked Questions',
                  style: GoogleFonts.nunito(
                      color: AppTheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // FAQS
              if (UserSession().role == 'Driver') ...[
                Text('Salary & Operations', style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      _buildFAQItem(context,
                        'How and when do I receive my salary?',
                        'All drivers are on a fixed monthly salary basis. Your salary is credited directly to your linked bank account at the end of each billing cycle. You do not need to manage a digital wallet for your personal earnings within the app.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'What should I do with cash collected from customers?',
                        'Any cash fares collected from customers during your shift belong to the company. Please submit all cash collections to the admin hub at the end of your shift as per standard company policy.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'Why does my Daily Earning reset to zero?',
                        'To help you and the admin track your daily productivity, your "Daily Earning" (representing company revenue you generated) and "Rides Completed" counters automatically reset to zero every day at 12:00 AM.',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                Text('Ride Rules & Safety', style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      _buildFAQItem(context,
                        'Can a customer change their drop-off location during the trip?',
                        'No. To ensure accurate scheduling and battery management, mid-trip drop-off location changes are not permitted. Please complete the trip to the originally booked destination.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'How are penalties calculated if I am late for a pickup?',
                        'Punctuality is strictly monitored. If you arrive more than 3 minutes after the provided ETA, a late penalty is recorded on your shift. Consistent late arrivals may impact your monthly performance review.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'What should I do if my EV battery runs critically low?',
                        'Always monitor your battery percentage on the dashboard. If an emergency occurs mid-trip, safely pull over, inform the customer, and contact Parigo EV support immediately to arrange a backup vehicle.',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                Text('Vehicle & Maintenance', style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      _buildFAQItem(context,
                        'Where and when should I charge the EV?',
                        'Vehicles should be charged at designated Parigo EV hubs or approved charging stations between shifts or during approved downtimes. Do not attempt to charge the vehicle at unauthorized locations.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'What should I do if the EV has a mechanical issue or breakdown?',
                        'Do not attempt to repair the vehicle yourself. Tap the "SOS" or "Report Issue" button immediately to inform the support team, and wait for a maintenance unit to arrive.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'Am I responsible for cleaning the vehicle?',
                        'Yes. Drivers are expected to keep both the interior and exterior of the vehicle clean and sanitized. A clean car ensures a 5-star experience for our customers.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text('Customer Interactions', style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      _buildFAQItem(context,
                        'What if a customer damages the vehicle or is abusive?',
                        'Your safety is our priority. Do not engage in an argument. Pull over safely if necessary, use the SOS button, and report the passenger through the app immediately.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'Am I allowed to pick up offline passengers (street hails)?',
                        'No. For safety and insurance reasons, you must only pick up passengers assigned to you through the Parigo EV app. Unauthorized street rides are strictly prohibited.',
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // FAQS - BOOKING & RIDES
                Text('Booking & Rides', style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      _buildFAQItem(context,
                        'How do I schedule a ride?',
                        'On the home screen, tap "Schedule a Ride", select your pickup/dropoff locations, and pick your preferred date and time.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'What happens if my driver doesn\'t arrive?',
                        'If your driver doesn\'t arrive within 15 minutes of your scheduled time, you can cancel without any penalty and we will assist in rebooking.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'Can I change my destination?',
                        'Currently, destinations must be fixed at the time of booking to ensure accurate range calculations for our EVs.',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                // FAQS - PAYMENTS & WALLET
                Text('Payments & Wallet', style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      _buildFAQItem(context,
                        'How do refunds work?',
                        'Refunds for cancelled rides or disputes will be credited to your Parigo Wallet instantly, or sent to your original payment method within 3-5 business days.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'How do I apply a coupon?',
                        'During the booking process, tap on the "Apply Coupon" section before confirming the ride to enter your promo code.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // FAQS - EV & SAFETY
                Text('Safety & EVs', style: const TextStyle(color: AppTheme.primaryContainer, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      _buildFAQItem(context,
                        'What if the EV runs out of charge during my trip?',
                        'Our system ensures drivers have enough range before they are dispatched. If an issue occurs, a backup cab is dispatched immediately at no extra cost.',
                      ),
                      const Divider(color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildFAQItem(context,
                        'Are the EVs sanitized?',
                        'Yes! All our fleet vehicles undergo rigorous sanitization before and after every ride.',
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              
              // LEGAL
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalPoliciesScreen()));
                  },
                  child: const Text('Privacy Policy & Terms of Service', style: TextStyle(color: AppTheme.primaryContainer, decoration: TextDecoration.underline)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
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
      ),
    );
  }
}

