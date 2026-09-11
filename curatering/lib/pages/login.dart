import 'package:flutter/material.dart';
import '../config/site_routes.dart';
import 'forgot_password.dart';
import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../widgets/antd_dialog.dart';
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
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _onLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Email Address and Password are required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resp = await AuthApi.instance.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Check if user is verified
      if (resp.user.isVerified == false) {
        final verified = await showStaffVerifyOtpDialog(
          context,
          email: email,
        );
        if (!mounted) return;
        if (verified == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account verified! You can log in.')),
          );
        }
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
        Role.superAdmin => '/dashboard',
        Role.supervisor => '/manage-events',
        Role.manager => '/manage-events',
        Role.cashier => '/restaurant-orders',
      };

      if (!mounted) return;

      await showCurateringSuccessDialog(
        context: context,
        title: 'Successful login!',
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(targetRoute);
    } on ApiError catch (e) {
      if (!mounted) return;

      if (e.statusCode == 429 ||
          e.message.contains('reached the limit for failed login')) {
        setState(() => _errorMessage = null);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Too many attempts'),
            content: Text(
              e.message.contains('15 minutes')
                  ? e.message
                  : 'You have reached the limit for failed login attempts. Try again after 15 minutes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (e.message.contains("not verified")) {
        final verified = await showStaffVerifyOtpDialog(
          context,
          email: _emailController.text.trim(),
        );
        if (!mounted) return;
        if (verified == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account verified! You can log in.')),
          );
        }
        return;
      }

      _emailController.clear();
      _passwordController.clear();
      setState(
        () => _errorMessage =
            e.message.trim().isEmpty
                ? 'Invalid credentials. Please try again.'
                : e.message,
      );
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
                color: Colors.white,
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
                      const SizedBox(height: 12),
                      Center(
                        child: Image.asset(
                          'lib/assets/login-2.png',
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _emailController,
                        enableInteractiveSelection: true,
                        style: const TextStyle(color: Color(0xFF1E1E1E)),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          labelStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFFC024)),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        enableInteractiveSelection: true,
                        style: const TextStyle(color: Color(0xFF1E1E1E)),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFFC024)),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _onLogin(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: const Color(0xFF1E1E1E),
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
                                    color: Color(0xFF1E1E1E),
                                  ),
                                )
                              : const Text(
                                  'Log in',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
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
                            color: Color(0xFFFFC024),
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (isCustomerSiteHost) {
                            Navigator.of(context).pushNamed('/');
                          } else {
                            redirectToSiteOrigin(customerSiteOrigin, '/');
                          }
                        },
                        child: const Text(
                          'View customer website',
                          style: TextStyle(
                            color: Color(0xFF7ED4E5),
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
    // Login stays light even when staff dark mode is on.
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F4F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC024),
          brightness: Brightness.light,
        ),
      ),
      child: Scaffold(
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
      ),
    );
  }
}
