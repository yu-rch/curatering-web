import 'package:flutter/material.dart';
import 'dart:math';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  int _currentStep = 1; // Step 1, 2, or 3
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _otpFields =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  String _maskedEmail = '';
  bool _isLoading = false;
  String _generatedOtp = '';

  // Countdown timer for resend
  int _resendCountdown = 0;
  late final Duration _resendDelay = const Duration(seconds: 30);

  // Generate 6-digit random code
  String _generateOtp() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    for (final c in _otpFields) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // Step 1: Verify email and send OTP
  Future<void> _verifyEmail() async {
    if (_emailController.text.isEmpty) {
      _showErrorSnackbar('Please enter your email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 2));

      // Generate 6-digit random code
      _generatedOtp = _generateOtp();
      
      // Mask email for display
      final email = _emailController.text;
      String maskedEmail = '';
      if (email.contains('@')) {
        final parts = email.split('@');
        final username = parts[0];
        final domain = parts[1];
        if (username.length > 2) {
          maskedEmail = '${username.substring(0, 2)}***@${domain}';
        } else {
          maskedEmail = '${username.substring(0, 1)}***@${domain}';
        }
      } else {
        maskedEmail = email;
      }

      setState(() {
        _maskedEmail = maskedEmail;
        _currentStep = 2;
        _isLoading = false;
        _startResendCountdown();
      });

      if (mounted) {
        _showSuccessSnackbar('6-digit code sent to $maskedEmail');
        print('Generated OTP: $_generatedOtp'); // For debugging
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error: ${e.toString()}');
      }
      setState(() => _isLoading = false);
    }
  }

  // Step 2: Verify OTP code
  Future<void> _verifyOtp() async {
    final otp = _otpFields.map((c) => c.text).join();
    _otpController.text = otp;

    if (otp.isEmpty || otp.length < 6) {
      _showErrorSnackbar('Please enter a valid 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 2));

      // Verify against the generated OTP
      if (otp != _generatedOtp) {
        throw Exception('Invalid code');
      }

      setState(() {
        _currentStep = 3;
        _isLoading = false;
      });

      if (mounted) {
        _showSuccessSnackbar('Code verified successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Invalid code. Please try again.');
      }
      setState(() => _isLoading = false);
    }
  }

  // Step 2: Resend OTP code
  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
      _startResendCountdown();
    });

    try {
      await Future.delayed(const Duration(seconds: 2));

      // Generate new OTP
      _generatedOtp = _generateOtp();

      setState(() => _isLoading = false);

      if (mounted) {
        _showSuccessSnackbar('6-digit code resent to $_maskedEmail');
        print('New Generated OTP: $_generatedOtp'); // remove after debugging
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error resending code: ${e.toString()}');
      }
      setState(() => _isLoading = false);
    }
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = _resendDelay.inSeconds);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
        return true;
      }
      return false;
    });
  }

  /// Step 3: Reset password
  Future<void> _resetPassword() async {
    if (_passwordController.text.isEmpty) {
      _showErrorSnackbar('Please enter a new password');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorSnackbar('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _showSuccessSnackbar('Password reset successfully');
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error resetting password: ${e.toString()}');
      }
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Forgot password?',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    'Step $_currentStep',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF4511E),
                    ),
                  ),
                ),
              ),
              if (_currentStep == 1) ...[
                const Text('Enter your email',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'your.email@example.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
              if (_currentStep == 2) ...[
                Text(
                  "We've sent a 6-digit code to your email\n$_maskedEmail",
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please enter the code we\'ve sent',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      child: TextField(
                        controller: _otpFields[index],
                        focusNode: _otpFocusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) {
                          final otp = _otpFields.map((c) => c.text).join();
                          _otpController.text = otp;
                          
                          // Auto-focus next field when digit entered
                          if (value.isNotEmpty && index < 5) {
                            _otpFocusNodes[index + 1].requestFocus();
                          }
                          
                          // Auto-verify when all 6 digits entered
                          if (otp.length == 6) {
                            _verifyOtp();
                          }
                        },
                      ),
                    );
                  }),
                ),
              ],
              if (_currentStep == 3) ...[
                const Text(
                  'We need to reset your password for stronger security!',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                const Text('New Password',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  obscureText: true,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
        ),
        if (_currentStep == 1)
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4511E),
              disabledBackgroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Submit'),
          ),
        if (_currentStep == 2) ...[
          TextButton(
            onPressed: (_isLoading || _resendCountdown > 0) ? null : _resendOtp,
            child: Text(
              _resendCountdown > 0
                  ? 'Resend in $_resendCountdown s'
                  : 'Resend code',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4511E),
              disabledBackgroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
        if (_currentStep == 3)
          ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4511E),
              disabledBackgroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Save new password'),
          ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}