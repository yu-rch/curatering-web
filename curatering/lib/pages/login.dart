import 'package:flutter/material.dart';
import 'forgot_password.dart';
import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import 'verify_otp.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _onLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final resp = await AuthApi.instance.login(
        email: email,
        password: password,
      );

      if (!mounted) return;


      // Check if user is verified
      if (resp.user.isVerified == false) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerifyOtp(email: _emailController.text.trim()),
          ),
        );
        return;
      }
      AuthSession.instance.setSession(
        token: resp.token,
        user: UserProfile(
          id: resp.user.id,
          email: resp.user.email,
          fullName: resp.user.fullName,
          role: resp.user.role,
          isVerified: resp.user.isVerified,
          pagePermissions: resp.user.pagePermissions,
        ),
      );

      final role = resp.user.role;
      final targetRoute = switch (role) {
        Role.superAdmin => '/manage-accounts',
        Role.supervisor => '/dashboard',
        Role.manager => '/manage-events',
        Role.cashier => '/dashboard',
      };
      
      if (!mounted) {
        return;
      }
      
      Navigator.of(context).pushReplacementNamed(targetRoute);
    } on ApiError catch (e) {
      if (e.message.contains("not verified")) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerifyOtp(email: _emailController.text.trim()),
          ),
        );
        return;
      }

      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLeftPanel() {
    return Container(
      color: const Color(0xFFF4F4F6),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Image.asset('lib/assets/login-1.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      color: const Color(0xFFF4F4F6),
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome to',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                            children: [
                              TextSpan(
                                text: 'CURA',
                                style: TextStyle(color: Color(0xFFFFB300)),
                              ),
                              TextSpan(
                                text: 'TE',
                                style: TextStyle(color: Colors.black87),
                              ),
                              TextSpan(
                                text: 'RING',
                                style: TextStyle(color: Color(0xFFF4511E)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF4511E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Log in'),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => showDialog<String>(
                          context: context,
                          builder: (BuildContext context) =>
                              const ForgotPassword(),
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/'),
                        child: const Text(
                          'View customer website',
                          style: TextStyle(
                            color: Colors.black87,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            if (isNarrow) {
              return Column(
                children: [
                  Expanded(child: _buildLeftPanel()),
                  const Divider(height: 1),
                  Expanded(child: _buildRightPanel()),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: _buildLeftPanel()),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: _buildRightPanel()),
              ],
            );
          },
        ),
      ),
    );
  }
}
