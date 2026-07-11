import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../core/api_constants.dart';
import 'primary_button.dart';
import 'package:parigo_ev_app/core/api_client.dart';

class CreateCouponSheet extends StatefulWidget {
  final VoidCallback onCouponCreated;

  const CreateCouponSheet({Key? key, required this.onCouponCreated}) : super(key: key);

  @override
  State<CreateCouponSheet> createState() => _CreateCouponSheetState();
}

class _CreateCouponSheetState extends State<CreateCouponSheet> {
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _targetPhoneController = TextEditingController();

  String _discountType = 'PERCENTAGE'; // 'PERCENTAGE' or 'FLAT'
  String _targetType = 'ALL'; // 'ALL' or 'INDIVIDUAL'
  bool _isLoading = false;
  DateTime? _validityDate;

  @override
  void dispose() {
    _codeController.dispose();
    _discountValueController.dispose();
    _targetPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/admin/coupon/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': _codeController.text.trim().toUpperCase(),
          'discountType': _discountType,
          'discountValue': double.tryParse(_discountValueController.text.trim()) ?? 0.0,
          'targetType': _targetType,
          'targetPhone': _targetType == 'INDIVIDUAL' ? _targetPhoneController.text.trim() : null,
          'validityDate': _validityDate?.toIso8601String(),
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onCouponCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coupon generated successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(data['error'] ?? 'Failed to generate coupon');
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

  Future<void> _selectValidityDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _validityDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryContainer,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceContainerHigh,
              onSurface: AppTheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _validityDate = picked;
      });
    }
  }

  Widget _buildValidityDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COUPON VALIDITY DATE (OPTIONAL)', style: TextStyle(color: AppTheme.primaryContainer, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectValidityDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _validityDate == null 
                        ? 'Select validity/expiry date' 
                        : '${_validityDate!.day}/${_validityDate!.month}/${_validityDate!.year}',
                    style: TextStyle(
                      color: _validityDate == null ? AppTheme.onSurfaceVariant : AppTheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.calendar_today, color: AppTheme.primaryContainer, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountTypeToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DISCOUNT TYPE', style: TextStyle(color: AppTheme.primaryContainer, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountType = 'PERCENTAGE'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _discountType == 'PERCENTAGE' ? AppTheme.primaryContainer : AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Percentage (%)',
                      style: TextStyle(
                        color: _discountType == 'PERCENTAGE' ? Colors.white : AppTheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountType = 'FLAT'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _discountType == 'FLAT' ? AppTheme.primaryContainer : AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Flat (₹)',
                      style: TextStyle(
                        color: _discountType == 'FLAT' ? Colors.white : AppTheme.onSurface,
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

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, int? maxLength, bool isRequired = true, String? hintText}) {
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
          hintText: hintText,
          hintStyle: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
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
            Text('Generate Discount Coupon',
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
                      _buildTextField('Coupon Code', _codeController, hintText: 'e.g. WELCOME50'),
                      _buildDiscountTypeToggle(),
                      _buildTextField('Discount Value', _discountValueController, isNumber: true, hintText: _discountType == 'PERCENTAGE' ? 'e.g. 15 (for 15%)' : 'e.g. 50 (for ₹50)'),
                      _buildTargetTypeToggle(),
                      if (_targetType == 'INDIVIDUAL')
                        _buildTextField('Customer Mobile Number', _targetPhoneController, hintText: 'e.g. +919876543210'),
                      _buildValidityDatePicker(),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                          : PrimaryButton(
                              text: 'Create Coupon',
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
