import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_constants.dart';
import 'customer_main_screen.dart';
import 'driver_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class FeedbackScreen extends StatefulWidget {
  final String role; // 'Customer' or 'Driver'
  final String rideId;
  final String otherPartyName; // e.g. Driver's name or Customer's name

  const FeedbackScreen({
    super.key,
    required this.role,
    required this.rideId,
    required this.otherPartyName,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  void _returnToHome() {
    if (widget.role == 'Customer') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const CustomerMainScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DriverDashboardScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a star rating.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/ride/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rideId': widget.rideId,
          'role': widget.role,
          'rating': _rating,
          'feedback': _feedbackController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for your feedback!')));
        _returnToHome();
      } else {
        throw Exception('Failed to submit feedback');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading:
            false, // Prevent going back without submitting or skipping explicitly
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Ride Completed',
            style: GoogleFonts.nunito(color: AppTheme.primaryContainer)),
        actions: [
          TextButton(
            onPressed: () => _returnToHome(),
            child: const Text('SKIP',
                style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.1),
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 80),
              ),
              const SizedBox(height: 24),
              Text(
                'How was your ride?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Rate your experience with ${widget.otherPartyName}',
                style: const TextStyle(
                    color: AppTheme.onSurfaceVariant, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    iconSize: 48,
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: index < _rating
                          ? Colors.amber
                          : AppTheme.surfaceContainerHighest,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 40),

              // Feedback Text Field
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  style: const TextStyle(color: AppTheme.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'Add additional comments (optional)...',
                    hintStyle: TextStyle(color: AppTheme.onSurfaceVariant),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              _isLoading
                  ? const CircularProgressIndicator(
                      color: AppTheme.primaryContainer)
                  : PrimaryButton(
                      text: 'SUBMIT FEEDBACK',
                      onPressed: _submitFeedback,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
