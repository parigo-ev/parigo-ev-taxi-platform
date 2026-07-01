import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import 'primary_button.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class AddAdminSheet extends StatefulWidget {
  final VoidCallback onAdminAdded;

  const AddAdminSheet({Key? key, required this.onAdminAdded}) : super(key: key);

  @override
  State<AddAdminSheet> createState() => _AddAdminSheetState();
}

class _AddAdminSheetState extends State<AddAdminSheet> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/admins/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'pin': _pinController.text.trim(),
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onAdminAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin added successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(data['error'] ?? 'Failed to add admin');
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

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, int? maxLength, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        style: const TextStyle(color: AppTheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
          filled: true,
          fillColor: AppTheme.surfaceContainerHighest.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          counterText: '',
        ),
        validator: isRequired ? (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        } : null,
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
            // Handle
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
            Text('Add New Admin',
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
                      _buildTextField('Full Name', _nameController),
                      _buildTextField('Phone Number (e.g. +91...)', _phoneController),
                      _buildTextField('4-Digit Login PIN', _pinController, isNumber: true, maxLength: 4),
                      _buildTextField('Email (Optional)', _emailController, isRequired: false),
                      
                      const SizedBox(height: 16),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                          : PrimaryButton(
                              text: 'Create Admin',
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
