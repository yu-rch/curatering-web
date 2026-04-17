import 'dart:math';
import 'package:curatering/services/auth_api.dart';
import 'package:flutter/material.dart';

class VerifyOtp extends StatefulWidget {
  final String email;

  const VerifyOtp({super.key, required this.email});

  @override
  State<VerifyOtp> createState() => _VerifyOtpState();
}

class _VerifyOtpState extends State<VerifyOtp> {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _generatedOtp;

  // Generate OTP function (for cases where OTP needs to be generated)
  String _generateOtp() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  // Request new OTP function
  Future<void> _requestNewOtp() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Generate new OTP
      _generatedOtp = _generateOtp();
      
      // In a real implementation, this would call an API to send OTP
      // For now, we'll simulate the API call
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("New OTP sent to your email")),
        );
      }
    } catch (e) {
      setState(() {
        _error = "Failed to send OTP";
        _loading = false;
      });
    }
  }

  Future<void> _verify() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthApi.instance.verifyOtp(
        email: widget.email,
        otp: _otpController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account verified! You can now log in.")),
      );

      Navigator.pop(context); // back to login
    } catch (e) {
      setState(() => _error = "Invalid or expired OTP");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(title: const Text("Verify Account")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Enter OTP",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We sent a code to ${widget.email}",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_generatedOtp != null)
                    Text(
                      "Generated OTP: $_generatedOtp",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _otpController,
                    decoration: InputDecoration(
                      labelText: "OTP Code",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _verify,
                          child: _loading
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Text("Verify"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _loading ? null : _requestNewOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                        ),
                        child: const Text("Resend OTP"),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}