import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../widgets/antd_dialog.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  int _currentStep = 1;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _otpFields =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String _maskedEmail = '';
  String _verifiedOtp = '';
  bool _isLoading = false;
  String? _alertMessage;
  bool _alertSuccess = false;

  int _resendCountdown = 0;
  static const _resendDelay = Duration(seconds: 30);

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

  void _setAlert(String message, {bool success = false}) {
    setState(() {
      _alertMessage = message;
      _alertSuccess = success;
    });
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final username = parts[0];
    final domain = parts[1];
    if (username.length > 2) {
      return '${username.substring(0, 2)}***@$domain';
    }
    return '${username.substring(0, 1)}***@$domain';
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setAlert('Email address is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _alertMessage = null;
    });

    try {
      await AuthApi.instance.forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _maskedEmail = _maskEmail(email);
        _currentStep = 2;
        _isLoading = false;
      });
      _setAlert('OTP sent!', success: true);
      _startResendCountdown();
    } on ApiError catch (e) {
      if (!mounted) return;
      _setAlert(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      _setAlert('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpFields.map((c) => c.text).join();
    _otpController.text = otp;

    if (otp.isEmpty) {
      _setAlert('Please enter the 6-digit code sent to your email');
      return;
    }
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      _setAlert('This OTP is invalid');
      return;
    }

    setState(() {
      _isLoading = true;
      _alertMessage = null;
    });

    try {
      await AuthApi.instance.verifyResetOtp(
        email: _emailController.text.trim(),
        otp: otp,
      );
      if (!mounted) return;
      setState(() {
        _verifiedOtp = otp;
        _currentStep = 3;
        _isLoading = false;
        _alertMessage = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      _setAlert(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      _setAlert('This OTP is invalid');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
      _alertMessage = null;
    });

    try {
      await AuthApi.instance.forgotPassword(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      for (final c in _otpFields) {
        c.clear();
      }
      _setAlert('OTP sent!', success: true);
      _startResendCountdown();
      setState(() => _isLoading = false);
    } on ApiError catch (e) {
      if (!mounted) return;
      _setAlert(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      _setAlert('Error resending code: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = _resendDelay.inSeconds);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
        return true;
      }
      return false;
    });
  }

  Future<void> _resetPassword() async {
    if (_passwordController.text.isEmpty) {
      _setAlert('Please enter a new password');
      return;
    }
    if (_passwordController.text.length < 6) {
      _setAlert('Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _alertMessage = null;
    });

    try {
      await AuthApi.instance.resetPassword(
        email: _emailController.text.trim(),
        otp: _verifiedOtp.isNotEmpty
            ? _verifiedOtp
            : _otpFields.map((c) => c.text).join(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      await showCurateringSuccessDialog(
        context: context,
        title: 'Password reset successful',
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (!mounted) return;
      _setAlert(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      _setAlert('Error resetting password: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget? _alertBanner() {
    if (_alertMessage == null || _alertMessage!.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        _alertMessage!,
        style: TextStyle(
          color: _alertSuccess ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
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
                padding: const EdgeInsets.only(bottom: 12),
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
              if (_alertBanner() != null) _alertBanner()!,
              if (_currentStep == 1) ...[
                const Text(
                  'Enter your email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  enableInteractiveSelection: true,
                  decoration: InputDecoration(
                    hintText: 'your.email@example.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_alertMessage != null) {
                      setState(() => _alertMessage = null);
                    }
                  },
                ),
              ],
              if (_currentStep == 2) ...[
                Text(
                  "We've sent a 6-digit code to your email\n$_maskedEmail",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Please enter the code we've sent",
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
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) {
                          final otp = _otpFields.map((c) => c.text).join();
                          _otpController.text = otp;
                          if (value.isNotEmpty && index < 5) {
                            _otpFocusNodes[index + 1].requestFocus();
                          }
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
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  enableInteractiveSelection: true,
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
