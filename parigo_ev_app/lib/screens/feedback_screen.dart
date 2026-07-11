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
  final Set<String> _selectedTags = {};

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

  List<String> _getTemplates() {
    if (widget.role == 'Customer') {
      if (_rating >= 4) {
        return [
          'Smooth Ride 🚗',
          'Clean EV ⚡',
          'Polite Driver 🤝',
          'Safe Driving 🛡️',
          'Great Route 🧭',
        ];
      } else {
        return [
          'Reckless Driving ⚠️',
          'Vehicle Unclean 🧹',
          'Rude Behavior 😡',
          'Delayed Arrival ⏰',
          'Wrong Route 🗺️',
        ];
      }
    } else {
      if (_rating >= 4) {
        return [
          'Polite Rider 🤝',
          'On Time ⏱️',
          'Great Conversation 💬',
          'Respectful 😇',
        ];
      } else {
        return [
          'Kept Me Waiting ⏳',
          'Rude Rider 😡',
          'Unreasonable Request 🙅',
          'No Show 🚫',
        ];
      }
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

    final String comment = _feedbackController.text.trim();
    final List<String> feedbackParts = [];
    if (_selectedTags.isNotEmpty) {
      feedbackParts.add(_selectedTags.join(', '));
    }
    if (comment.isNotEmpty) {
      feedbackParts.add(comment);
    }
    final String finalFeedback = feedbackParts.join('. ');

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/ride/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rideId': widget.rideId,
          'role': widget.role,
          'rating': _rating,
          'feedback': finalFeedback,
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
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
                        _selectedTags.clear();
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Quick Feedback Templates
              if (_rating > 0) ...[
                Text(
                  'Quick Feedback',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _getTemplates().map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: _rating >= 4 ? AppTheme.primary : AppTheme.error,
                      checkmarkColor: Colors.white,
                      backgroundColor: AppTheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: isSelected 
                              ? (_rating >= 4 ? AppTheme.primary : AppTheme.error)
                              : AppTheme.outline,
                          width: 1,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

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
