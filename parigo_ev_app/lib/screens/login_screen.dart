import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../core/api_constants.dart';
import '../core/user_session.dart';
import 'customer_main_screen.dart';
import 'driver_live_photo_screen.dart';
import 'admin_dashboard_screen.dart';
import 'edit_profile_screen.dart';
import 'onboarding_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import '../widgets/parigo_logo.dart';
import 'package:parigo_ev_app/core/api_client.dart';
import '../services/push_notification_service.dart';

enum LoginState { phone, pin, otp, setPin }

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _setPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  LoginState _loginState = LoginState.phone;
  bool _isLoading = false;
  String _formattedPhone = '';
  String? _uid;
  String? _verificationId;
  bool _termsAccepted = false;
  bool _isVerifyingOtp = false;
  static const int _maxOtpResends = 3;
  static const int _resendDelaySeconds = 30;
  int _resendAttempts = 0;
  int _secondsUntilResend = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _otpController.dispose();
    _setPinController.dispose();
    _confirmPinController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _resetOtpResendState() {
    _resendTimer?.cancel();
    _resendAttempts = 0;
    _secondsUntilResend = 0;
  }

  void _startOtpResendTimer() {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _secondsUntilResend = _resendDelaySeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
      } else {
        setState(() => _secondsUntilResend--);
      }
    });
  }

  void _handleNetworkError(dynamic e) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    final errorStr = e.toString();
    if (errorStr.contains('SocketException') ||
        errorStr.contains('Failed host lookup') ||
        errorStr.contains('ClientException')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Failed'),
          content: const Text(
              'Oops! We couldn\'t connect to the server. Please check your internet connection, disable any active VPNs, and try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _checkUser() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit mobile number')),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please accept the Terms of Service to continue')));
      return;
    }

    _formattedPhone = '+91$phone';
    _resetOtpResendState();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/check-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _formattedPhone, 'role': widget.role}),
        handleUnauthorized: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['userExists'] == true && data['hasPin'] == true) {
          setState(() {
            _loginState = LoginState.pin;
            _isLoading = false;
          });
        } else {
          // Trigger OTP for new user or existing user without PIN
          _sendOTP();
        }
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Unauthorized access.');
      } else {
        throw Exception('Server error');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<void> _verifyPIN({String? autoPin}) async {
    final pin = autoPin ?? _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/verify-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _formattedPhone, 'pin': pin}),
        handleUnauthorized: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customToken = data['customToken'];

        try {
          await FirebaseAuth.instance.signInWithCustomToken(customToken);
          _uid = data['uid'];
          UserSession().setUserDetails(
              phone: _formattedPhone,
              uid: _uid!,
              role: data['role'] ?? widget.role);
          await UserSession().saveSession();
          PushNotificationService().syncTokenForCurrentUser();
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Login Successful!')));
          _navigateToDashboard();
        } catch (fbErr) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Firebase Auth Error: $fbErr')));
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _pinController.clear();
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Incorrect PIN')),
        );
      }
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  void _sendOTP({bool isResend = false}) async {
    if (_isVerifyingOtp) return;
    setState(() {
      _isLoading = true;
      _isVerifyingOtp = true;
    });

    // Fixes the "missing initial state" error by bypassing the browser reCAPTCHA
    // await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (often works on Android without entering code)
          try {
            final userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final idToken = await userCredential.user!.getIdToken();
            await _verifyTokenWithBackend(idToken!);
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isVerifyingOtp = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Auto-verification failed: $e')));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isVerifyingOtp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification Failed: ${e.message}')));
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isVerifyingOtp = false;
            _verificationId = verificationId;
            _loginState = LoginState.otp;
            if (isResend) {
              _resendAttempts++;
            }
          });
          _startOtpResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isResend
                  ? 'A new OTP has been sent.'
                  : 'OTP sent to your phone!'),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isVerifyingOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send OTP: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isVerifyingOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send OTP: $error')),
      );
    }
  }

  void _resendOTP() {
    if (_isVerifyingOtp ||
        _secondsUntilResend > 0 ||
        _resendAttempts >= _maxOtpResends) {
      return;
    }
    _otpController.clear();
    _sendOTP(isResend: true);
  }

  void _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user!.getIdToken();
      await _verifyTokenWithBackend(idToken!);
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incorrect or expired OTP. Please try again.')));
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<void> _verifyTokenWithBackend(String idToken) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'mockPhone': _formattedPhone,
          'role': widget.role
        }),
        handleUnauthorized: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _uid = data['uid'];
        _resendTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isVerifyingOtp = false;
          _secondsUntilResend = 0;
        });

        if (data['isNewUser'] == true) {
          final registrationCompleted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfileScreen(
                initialPhone: _formattedPhone,
                isRegistration: true,
              ),
            ),
          );
          if (!mounted) return;
          if (registrationCompleted != true) {
            return;
          }
        }

        setState(() {
          _loginState = LoginState.setPin;
        });
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Unauthorized access.');
      } else {
        throw Exception('Failed to verify OTP with backend');
      }
    } catch (e) {
      _isVerifyingOtp = false;
      _handleNetworkError(e);
    }
  }

  Future<void> _setPIN() async {
    final pin = _setPinController.text.trim();
    final confirmation = _confirmPinController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN must contain exactly 4 digits')));
      return;
    }
    if (pin != confirmation) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PINs do not match. Please try again.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/set-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _formattedPhone, 'pin': pin}),
        handleUnauthorized: false,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        // OTP authentication is only for PIN creation. Require the normal
        // number-and-PIN login afterwards, so this flow is explicit and safe.
        await FirebaseAuth.instance.signOut();
        await UserSession().clear();
        _phoneController.clear();
        _pinController.clear();
        _setPinController.clear();
        _confirmPinController.clear();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loginState = LoginState.phone;
          _termsAccepted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'PIN created. Please sign in with your number and PIN.')),
        );
      } else {
        throw Exception('Failed to set PIN');
      }
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  void _navigateToDashboard() {
    if (widget.role == 'Admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } else if (widget.role == 'Driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                DriverLivePhotoScreen(driverId: _uid ?? 'unknown')),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomerMainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.0,
              height: MediaQuery.of(context).size.width * 1.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryContainer.withOpacity(0.1),
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 64),
                  const ParigoLogo(),
                  const SizedBox(height: 12),
                  Text(
                    'Electrify your journey.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.bolt,
                        size: 80, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildInputField(),
                        const SizedBox(height: 24),
                        if (_loginState == LoginState.phone) ...[
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (val) {
                                    setState(() {
                                      _termsAccepted = val ?? false;
                                    });
                                  },
                                  activeColor: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'I agree to the Terms of Service and Privacy Policy',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppTheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_isLoading)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.primary))
                        else
                          PrimaryButton(
                            text: _getButtonText(),
                            icon: Icons.arrow_forward,
                            onPressed: _getButtonAction(),
                          ),
                        if (_loginState == LoginState.otp) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _secondsUntilResend == 0 &&
                                      _resendAttempts < _maxOtpResends &&
                                      !_isVerifyingOtp
                                  ? _resendOTP
                                  : null,
                              child: Text(
                                _resendAttempts >= _maxOtpResends
                                    ? 'Resend limit reached'
                                    : _secondsUntilResend > 0
                                        ? 'Resend OTP in ${_secondsUntilResend}s'
                                        : 'Resend OTP',
                                style: TextStyle(
                                  color: _secondsUntilResend == 0 &&
                                          _resendAttempts < _maxOtpResends
                                      ? AppTheme.primaryContainer
                                      : AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '${_maxOtpResends - _resendAttempts} resend attempts remaining',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                        if (_loginState == LoginState.pin) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: _startForgotPinFlow,
                              child: const Text('Forgot PIN? Login with OTP',
                                  style: TextStyle(
                                      color: AppTheme.primaryContainer)),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const TermsOfServiceScreen()),
                            );
                          },
                          child: const Text('Terms of Service',
                              style:
                                  TextStyle(color: AppTheme.onSurfaceVariant))),
                      const SizedBox(width: 24),
                      TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const PrivacyPolicyScreen()),
                            );
                          },
                          child: const Text('Privacy Policy',
                              style:
                                  TextStyle(color: AppTheme.onSurfaceVariant))),
                    ],
                  )
                ],
              ),
            ),
          ),

          // Top Left Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const OnboardingScreen()),
                    );
                  }
                },
              ),
            ),
          ),

          // Top Right Role Switcher (Only for Customers)
          if (widget.role == 'Customer')
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(role: 'Driver'))),
                      child: const Icon(Icons.directions_car,
                          color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 20),
                    InkWell(
                      onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(role: 'Admin'))),
                      child: const Icon(Icons.admin_panel_settings,
                          color: AppTheme.primary, size: 24),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _startForgotPinFlow() {
    // The phone number was just verified by the preceding number step, so
    // reset its PIN directly rather than asking the user to enter it again.
    if (_formattedPhone.isEmpty) {
      setState(() => _loginState = LoginState.phone);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your mobile number first.')),
      );
      return;
    }

    setState(() {
      _resetOtpResendState();
      _isVerifyingOtp = false;
      _verificationId = null;
      _pinController.clear();
      _otpController.clear();
      _setPinController.clear();
      _confirmPinController.clear();
    });
    _sendOTP();
  }

  Widget _buildHeader() {
    String title;
    String subtitle;

    switch (_loginState) {
      case LoginState.phone:
        if (widget.role == 'Driver') {
          title = 'Welcome Back Driver';
        } else if (widget.role == 'Admin') {
          title = 'Welcome to Admin Panel';
        } else {
          title = 'Welcome to Parigo EV';
        }
        subtitle = 'Enter your mobile number to ignite.';
        break;
      case LoginState.pin:
        title = 'Enter PIN';
        subtitle = 'Enter your 4-digit security PIN.';
        break;
      case LoginState.otp:
        title = 'Verify OTP';
        subtitle = 'Enter the code sent to your phone.';
        break;
      case LoginState.setPin:
        title = 'Set Secure PIN';
        subtitle = 'Create and confirm a 4-digit PIN for future logins.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildInputField() {
    String label;
    IconData icon;
    TextEditingController controller;
    TextInputType keyboardType = TextInputType.number;
    bool obscureText = false;
    int? maxLength;

    switch (_loginState) {
      case LoginState.phone:
        label = 'MOBILE NUMBER';
        icon = Icons.phone_iphone;
        controller = _phoneController;
        keyboardType = TextInputType.phone;
        maxLength = 10;
        break;
      case LoginState.pin:
        label = '4-DIGIT PIN';
        icon = Icons.lock;
        controller = _pinController;
        obscureText = true;
        maxLength = 4;
        break;
      case LoginState.otp:
        label = 'OTP CODE';
        icon = Icons.message;
        controller = _otpController;
        maxLength = 6;
        break;
      case LoginState.setPin:
        label = 'NEW 4-DIGIT PIN';
        icon = Icons.lock_outline;
        controller = _setPinController;
        obscureText = true;
        maxLength = 4;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppTheme.secondary, letterSpacing: 2)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            children: [
              if (_loginState == LoginState.phone)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('+91',
                      style: TextStyle(
                          fontSize: 18, color: AppTheme.onSurfaceVariant)),
                ),
              if (_loginState == LoginState.phone)
                Container(width: 1, height: 24, color: AppTheme.outline),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  maxLength: maxLength,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    counterText: "",
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(icon, color: AppTheme.primaryContainer),
              ),
            ],
          ),
        ),
        if (_loginState == LoginState.setPin) ...[
          const SizedBox(height: 16),
          Text('CONFIRM 4-DIGIT PIN',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppTheme.secondary, letterSpacing: 2)),
          const SizedBox(height: 8),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh.withOpacity(0.5),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child:
                      Icon(Icons.lock_reset, color: AppTheme.primaryContainer),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getButtonText() {
    switch (_loginState) {
      case LoginState.phone:
        return 'Continue';
      case LoginState.pin:
        return 'Login';
      case LoginState.otp:
        return 'Verify';
      case LoginState.setPin:
        return 'Create PIN';
    }
  }

  VoidCallback _getButtonAction() {
    switch (_loginState) {
      case LoginState.phone:
        return _checkUser;
      case LoginState.pin:
        return _verifyPIN;
      case LoginState.otp:
        return _verifyOTP;
      case LoginState.setPin:
        return _setPIN;
    }
  }
}
