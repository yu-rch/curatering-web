import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../services/api_client.dart';
import '../services/cart_sync_service.dart';
import '../utils/responsive_layout.dart';

Uri _apiUri(String path) {
  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return Uri.parse('$base$path');
}

const _requestTimeout = Duration(seconds: 30);

final _nameAlphabetPattern = RegExp(r'^[A-Za-z]+(?:\s+[A-Za-z]+)*$');

class CustomerLoginPage extends StatefulWidget {
  final bool? redirectToCheckout;
  const CustomerLoginPage({super.key, this.redirectToCheckout});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _showOtpField = false;
  bool _showForgotPassword = false;
  bool _showResetPassword = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureNewPassword = true;
  String? _pendingEmail;
  String? _resetEmail;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _confirmPasswordController.dispose();
    _resetCodeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            _apiUri('/api/customer/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': _emailController.text.trim()}),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _resetEmail = _emailController.text.trim();
          _showForgotPassword = false;
          _showResetPassword = true;
          _errorMessage = null;
        });
      } else {
        setState(
          () =>
              _errorMessage =
                  data['error']?.toString() ??
                  data['message']?.toString() ??
                  data['detail']?.toString() ??
                  'Failed to send reset code (${response.statusCode})',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (_resetCodeController.text.isEmpty ||
        _resetCodeController.text.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit reset code');
      return;
    }
    if (_newPasswordController.text.isEmpty ||
        _newPasswordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            _apiUri('/api/customer/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _resetEmail,
              'resetCode': _resetCodeController.text.trim(),
              'newPassword': _newPasswordController.text,
            }),
          )
          .timeout(_requestTimeout);

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (response.statusCode == 200) {
        setState(() {
          _showResetPassword = false;
          _isLoginMode = true;
          _resetCodeController.clear();
          _newPasswordController.clear();
          _passwordController.clear();
          _errorMessage = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset successful. Please log in.')),
          );
        }
      } else {
        setState(
          () =>
              _errorMessage =
                  data['error']?.toString() ??
                  data['message']?.toString() ??
                  data['detail']?.toString() ??
                  'Failed to reset password (${response.statusCode})',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            _apiUri('/api/customer/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save token
        final prefs = await SharedPreferences.getInstance();
        final token = data['token'] as String?;
        await prefs.setString('customer_token', token ?? '');
        await prefs.setString('customer_data', jsonEncode(data['customer']));
        ApiClient.instance.setCustomerBearer(token);
        await CartSyncService.instance.syncAfterLogin();

        if (mounted) {
          Navigator.of(context).pop(data);
        }
      } else if (response.statusCode == 403 &&
          data['requiresVerification'] == true) {
        setState(() {
          _showOtpField = true;
          _pendingEmail = _emailController.text.trim();
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = data['error'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            _apiUri('/api/customer/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
              'fullName': _fullNameController.text.trim(),
              'phone': _phoneController.text.trim(),
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() {
          _showOtpField = true;
          _pendingEmail = _emailController.text.trim();
          _errorMessage = null;
        });
      } else {
        final errorMsg =
            data['error'] ?? 'Signup failed (HTTP ${response.statusCode})';
        print('Signup error response: $data');
        setState(() => _errorMessage = errorMsg);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            _apiUri('/api/customer/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _pendingEmail,
              'otpCode': _otpController.text.trim(),
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Close dialog immediately on success
        if (mounted) {
          Navigator.of(context).pop({'verified': true, 'email': _pendingEmail});
        }
        return;
      } else {
        setState(() => _errorMessage = data['error'] ?? 'Verification failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobileWidth(context) ? 340 : 420,
        ),
        padding: appPagePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.black),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              _showOtpField
                  ? 'VERIFY EMAIL'
                  : _showForgotPassword
                  ? 'FORGOT PASSWORD'
                  : _showResetPassword
                  ? 'RESET PASSWORD'
                  : (_isLoginMode ? 'LOG IN' : 'SIGN UP'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_showForgotPassword) ...[
              // Forgot Password UI
              Text(
                'Enter your email to receive a reset code',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'EMAIL ADDRESS',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text(
                          'SEND RESET CODE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _showForgotPassword = false),
                child: const Text(
                  'BACK TO LOGIN',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ] else if (_showResetPassword) ...[
              // Reset Password UI
              Text(
                'Enter the 6-digit code sent to $_resetEmail',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Reset Code
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text('RESET CODE', style: TextStyle(fontSize: 11)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _resetCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // New Password
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text('NEW PASSWORD', style: TextStyle(fontSize: 11)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(
                              () =>
                                  _obscureNewPassword = !_obscureNewPassword,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleResetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text(
                          'RESET PASSWORD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap:
                    () => setState(() {
                      _showResetPassword = false;
                      _isLoginMode = true;
                    }),
                child: const Text(
                  'BACK TO LOGIN',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ] else if (_showOtpField) ...[
              // OTP Field
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit OTP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || value.length != 6) {
                    return 'Please enter a valid 6-digit OTP';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleVerifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 32,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text(
                          'VERIFY',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sign up fields
                    if (!_isLoginMode) ...[
                      // Full Name
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'FULL NAME',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _fullNameController,
                              style: const TextStyle(fontSize: 13),
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z\s]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                hintText: 'Letters only',
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Required';
                                }
                                if (!_nameAlphabetPattern.hasMatch(trimmed)) {
                                  return 'Letters only';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Phone
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'PHONE',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              maxLength: 11,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                hintText: '11 digits max',
                                counterText: '',
                              ),
                              validator: (value) {
                                final digits =
                                    (value ?? '').replaceAll(RegExp(r'\D'), '');
                                if (digits.isEmpty) {
                                  return 'Required';
                                }
                                if (digits.length > 11) {
                                  return 'Max 11 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Email
                    Row(
                      children: [
                        const SizedBox(
                          width: 100,
                          child: Text(
                            'EMAIL ADDRESS',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  !value.contains('@')) {
                                return 'Invalid email';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Password
                    Row(
                      children: [
                        const SizedBox(
                          width: 100,
                          child: Text(
                            'PASSWORD',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  value.length < 6) {
                                return 'Min 6 chars';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Confirm Password (signup only)
                    if (!_isLoginMode) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'RE-TYPE PASSWORD',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    );
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      const SizedBox(height: 20),
                    ],
                    // Submit Button
                    ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : (_isLoginMode ? _handleLogin : _handleSignup),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC024),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                _isLoginMode ? 'LOG IN' : 'SIGN IN',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Forgot password link (only in login mode)
              if (_isLoginMode)
                GestureDetector(
                  onTap: () => setState(() => _showForgotPassword = true),
                  child: const Text(
                    'FORGOT PASSWORD?',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Toggle mode link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLoginMode
                        ? "DON'T HAVE AN ACCOUNT? "
                        : "ALREADY HAVE AN ACCOUNT? ",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isLoginMode = !_isLoginMode),
                    child: Text(
                      _isLoginMode ? 'SIGN IN' : 'LOG IN',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
