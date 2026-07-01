import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/glass_card.dart';
import '../core/api_constants.dart';
import 'driver_dashboard_screen.dart';
import 'package:parigo_ev_app/core/api_client.dart';


class DriverLivePhotoScreen extends StatefulWidget {
  final String driverId;
  const DriverLivePhotoScreen({super.key, required this.driverId});

  @override
  State<DriverLivePhotoScreen> createState() => _DriverLivePhotoScreenState();
}

class _DriverLivePhotoScreenState extends State<DriverLivePhotoScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _image = File(photo.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to open camera: $e')));
    }
  }

  Future<void> _uploadPhotoAndContinue() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Image';

      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/driver/upload-photo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': widget.driverId,
          'image': dataUri,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Live photo verified successfully!')));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const DriverDashboardScreen()),
        );
      } else {
        throw Exception('Failed to upload photo');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'LIVE PHOTO VERIFICATION',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  color: AppTheme.primaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'For security purposes, you must take a live selfie to proceed to your dashboard.',
                style:
                    TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              GlassCard(
                child: Container(
                  width: 250,
                  height: 300,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural,
                                size: 80, color: AppTheme.primary),
                            SizedBox(height: 16),
                            Text('Align your face\nin the frame',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.onSurfaceVariant)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator(color: AppTheme.primary)
              else if (_image == null)
                PrimaryButton(
                  text: 'TAKE SELFIE',
                  icon: Icons.camera_alt,
                  onPressed: _takePhoto,
                )
              else
                Column(
                  children: [
                    PrimaryButton(
                      text: 'SUBMIT & CONTINUE',
                      onPressed: _uploadPhotoAndContinue,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _takePhoto,
                      child: const Text('RETAKE PHOTO',
                          style: TextStyle(
                              color: AppTheme.primaryContainer,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
