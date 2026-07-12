import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';

class ReportIssueScreen extends StatefulWidget {
  final String? preSelectedRideId;

  const ReportIssueScreen({Key? key, this.preSelectedRideId}) : super(key: key);

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedIssueType;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  final List<String> _issueTypes = [
    'Driver Behavior',
    'Payment Dispute',
    'Vehicle Condition',
    'Lost Item',
    'App Bug/Glitch',
    'Other'
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIssueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an issue type'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/user/support/tickets'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'rideId': widget.preSelectedRideId,
          'issueType': _selectedIssueType,
          'description': _descriptionController.text.trim(),
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your issue has been reported. We will contact you soon.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back after success
      } else {
        throw Exception(data['error'] ?? 'Failed to submit ticket');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        title: Text('Report an Issue',
            style: GoogleFonts.audiowide(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.preSelectedRideId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryContainer.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car, color: AppTheme.primaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Reporting for Ride ID: \n${widget.preSelectedRideId}',
                            style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Text('What type of issue are you facing?',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedIssueType,
                      hint: const Text('Select an issue', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                      dropdownColor: AppTheme.surfaceContainerHigh,
                      items: _issueTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, style: const TextStyle(color: AppTheme.onSurface)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedIssueType = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Please describe the issue in detail',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 6,
                  style: const TextStyle(color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surfaceContainerHighest.withOpacity(0.5),
                    hintText: 'Provide as much detail as possible so we can help you better...',
                    hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryContainer, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Please provide more details';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : PrimaryButton(
                        text: 'Submit Ticket',
                        onPressed: _submitTicket,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
