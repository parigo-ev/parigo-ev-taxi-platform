import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import 'primary_button.dart';
import 'package:parigo_ev_app/core/api_client.dart';

class SendNotificationSheet extends StatefulWidget {
  final VoidCallback onNotificationSent;

  const SendNotificationSheet({Key? key, required this.onNotificationSent}) : super(key: key);

  @override
  State<SendNotificationSheet> createState() => _SendNotificationSheetState();
}

class _SendNotificationSheetState extends State<SendNotificationSheet> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _targetPhoneController = TextEditingController();

  String _targetType = 'ALL'; // 'ALL' or 'INDIVIDUAL'
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/notifications/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
          'targetType': _targetType,
          'targetPhone': _targetType == 'INDIVIDUAL' ? _targetPhoneController.text.trim() : null,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onNotificationSent();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(data['error'] ?? 'Failed to send notification');
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

  Widget _buildTextField(String label, TextEditingController controller, {bool isMultiline = false, String? hintText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.primaryContainer,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: isMultiline ? 4 : 1,
            style: const TextStyle(color: AppTheme.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceContainerHighest.withOpacity(0.5),
              hintText: hintText,
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
                return '$label is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTypeToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TARGET AUDIENCE', style: TextStyle(color: AppTheme.primaryContainer, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _targetType = 'ALL'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _targetType == 'ALL' ? AppTheme.primaryContainer : AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'All Customers',
                      style: TextStyle(
                        color: _targetType == 'ALL' ? Colors.white : AppTheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _targetType = 'INDIVIDUAL'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _targetType == 'INDIVIDUAL' ? AppTheme.primaryContainer : AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Specific Customer',
                      style: TextStyle(
                        color: _targetType == 'INDIVIDUAL' ? Colors.white : AppTheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text('Send Notification',
                style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryContainer)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField('Title', _titleController, hintText: 'e.g. System Maintenance'),
                      _buildTextField('Message', _messageController, isMultiline: true, hintText: 'e.g. Service will be down for 2 hours.'),
                      _buildTargetTypeToggle(),
                      if (_targetType == 'INDIVIDUAL')
                        _buildTextField('Customer Mobile Number', _targetPhoneController, hintText: 'e.g. +919876543210'),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                          : PrimaryButton(
                              text: 'Send Notification',
                              onPressed: _submit,
                            ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
