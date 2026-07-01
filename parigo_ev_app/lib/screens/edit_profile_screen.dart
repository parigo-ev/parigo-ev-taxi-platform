import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import 'customer_main_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/permission_disclosure_dialog.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class EditProfileScreen extends StatefulWidget {
  final String? initialPhone;
  final bool isRegistration;
  const EditProfileScreen(
      {super.key, this.initialPhone, this.isRegistration = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  late TextEditingController _phoneController;
  final _newPinController = TextEditingController();

  bool _isLoading = false;
  String? _profilePictureUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _phoneController =
        TextEditingController(text: widget.initialPhone ?? UserSession().phone);
    if (!widget.isRegistration) {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConstants.baseUrl}/user/profile/${_phoneController.text}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            final nameParts = (data['name'] ?? '').split(' ');
            if (nameParts.isNotEmpty) {
              _firstNameController.text = nameParts.first;
              if (nameParts.length > 1) {
                _lastNameController.text = nameParts.sublist(1).join(' ');
              }
            }
            _emailController.text = data['email'] ?? '';
            _profilePictureUrl = data['profile_picture_url'];
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final accepted = await PermissionDisclosureDialog.show(
        context,
        title: 'Photo Library Access',
        message: 'Parigo EV requires access to your photo library so you can upload a profile picture for your account.',
        icon: Icons.photo_library,
      );

      if (accepted != true) return;

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 50,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/user/update-profile-picture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'imageBase64': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _profilePictureUrl = base64Image;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Failed to update picture on server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating picture: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });
    final name =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (widget.isRegistration) {
      final newPin = _newPinController.text.trim();
      if (newPin.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN must be 4 digits')));
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/user/update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'name': name, 'email': email}),
      );

      if (widget.isRegistration && response.statusCode == 200) {
        // Also set the PIN for the new user
        await ApiClient.post(
          Uri.parse('${ApiConstants.baseUrl}/auth/set-pin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
              {'phone': phone, 'pin': _newPinController.text.trim()}),
        );
      }

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')));
        if (widget.isRegistration) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const CustomerMainScreen()));
        } else {
          Navigator.pop(
              context, true); // Return true to indicate profile was updated
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePin() async {
    final newPin = _newPinController.text.trim();
    if (newPin.length < 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final phone = _phoneController.text.trim();

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/set-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'pin': newPin}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN changed successfully!')));
        _newPinController.clear();
      } else {
        throw Exception('Failed to change PIN');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
            widget.isRegistration ? 'Complete Registration' : 'Edit Profile',
            style: GoogleFonts.nunito(color: AppTheme.primaryContainer)),
        iconTheme: const IconThemeData(color: AppTheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.primaryContainer, width: 2),
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppTheme.surfaceContainerHighest,
                        backgroundImage: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                            ? MemoryImage(base64Decode(_profilePictureUrl!.split(',').last))
                            : null,
                        child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                            ? const Icon(Icons.person, size: 50, color: AppTheme.primary)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: AppTheme.onPrimaryContainer, size: 20),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),
              GlassCard(
                child: Column(
                  children: [
                    _buildTextField('First Name', _firstNameController),
                    const Divider(
                        color: AppTheme.surfaceContainerHighest, height: 1),
                    _buildTextField('Last Name', _lastNameController),
                    const Divider(
                        color: AppTheme.surfaceContainerHighest, height: 1),
                    _buildTextField('Email Address', _emailController),
                    const Divider(
                        color: AppTheme.surfaceContainerHighest, height: 1),
                    _buildTextField('Phone Number', _phoneController,
                        isReadOnly: true),
                    if (widget.isRegistration) ...[
                      const Divider(
                          color: AppTheme.surfaceContainerHighest, height: 1),
                      _buildTextField('Create 4-Digit PIN', _newPinController,
                          isObscure: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _updateProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: AppTheme.onPrimaryContainer)
                      : const Text('SAVE PROFILE CHANGES',
                          style: TextStyle(
                              color: AppTheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 40),
              if (!widget.isRegistration) ...[
                Text('SECURITY',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.primaryContainer, letterSpacing: 2)),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    children: [
                      _buildTextField('New 4-Digit PIN', _newPinController,
                          isObscure: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryContainer),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isLoading ? null : _changePin,
                    child: const Text('CHANGE PIN',
                        style: TextStyle(
                            color: AppTheme.primaryContainer,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isReadOnly = false,
      bool isObscure = false,
      TextInputType? keyboardType,
      int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: isReadOnly,
        obscureText: isObscure,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: TextStyle(
            color: isReadOnly ? AppTheme.onSurfaceVariant : AppTheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}
