import 'package:flutter/material.dart';
import '../config/site_routes.dart';
import 'forgot_password.dart';
import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../widgets/antd_dialog.dart';
import 'verify_otp.dart';

/// Staff login uses a fixed split palette (light logo | dark form) and does not
/// follow staff light/dark mode.
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  static const _leftBg = Color(0xFFF4F4F6);
  static const _rightBg = Color(0xFF1A1A1A);
  static const _cardBg = Color(0xFF2A2A2A);
  static const _fieldBg = Color(0xFF1F1F1F);
  static const _fieldBorder = Color(0xFF5A5A5A);
  static const _accent = Color(0xFFFFC024);
  static const _customerLink = Color(0xFF7ED4E5);

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

      if (e.message.contains('not verified')) {
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

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
      filled: true,
      fillColor: _fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildCurateringTitle() {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFFFC024),
          Color(0xFFFF8A1F),
          Color(0xFFE53935),
        ],
      ).createShader(bounds),
      child: const Text(
        'CURATERING',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          height: 1.1,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return ColoredBox(
      color: _leftBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Image.asset(
            'lib/assets/login-1.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return ColoredBox(
      color: _rightBg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  _buildCurateringTitle(),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    enableInteractiveSelection: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _accent,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    decoration: _fieldDecoration(hint: 'Email address'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    enableInteractiveSelection: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _accent,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onLogin(),
                    decoration: _fieldDecoration(
                      hint: 'Password',
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
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        disabledBackgroundColor: const Color(0xFFB8942A),
                        foregroundColor: const Color(0xFF1E1E1E),
                        elevation: 0,
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFF4D4F),
                        fontSize: 13,
                      ),
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
                        color: _accent,
                        decoration: TextDecoration.underline,
                        decorationColor: _accent,
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
                        color: _customerLink,
                        decoration: TextDecoration.underline,
                        decorationColor: _customerLink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fixed login chrome — ignore staff ThemeMode.dark / light.
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: _rightBg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _cardBg,
          onPrimary: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _accent,
          selectionColor: Color(0x66FFC024),
          selectionHandleColor: _accent,
        ),
      ),
      child: Scaffold(
        backgroundColor: _rightBg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              if (isNarrow) {
                return Column(
                  children: [
                    Expanded(flex: 2, child: _buildLeftPanel()),
                    Expanded(flex: 3, child: _buildRightPanel()),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildLeftPanel()),
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
