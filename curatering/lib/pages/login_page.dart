import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _onLogin() {
    // In a real app you'd validate credentials and talk to a backend
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  Widget _buildLeftPanel() {
    return Container(
      color: const Color(0xFFF4F4F6),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Image.asset(
            'lib/assets/login-1.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      color: Colors.white,
      child: Stack( 
        children: [
          // subtle background accent
          // Positioned.fill(
          //   child: Opacity(
          //     opacity: 0.08,
          //     child: Image.asset(
          //       'lib/assets/login-2.png',
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
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
                                fontFamily: 'Inter'),
                            children: [
                              TextSpan(
                                  text: 'CURA',
                                  style: TextStyle(color: Color(0xFFFFB300))),
                              TextSpan(
                                  text: 'TE',
                                  style: TextStyle(color: Colors.black87)),
                              TextSpan(
                                  text: 'RING',
                                  style: TextStyle(color: Color(0xFFF4511E))),
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
                          onPressed: _onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF4511E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Log in'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          // handle forgot password
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            // handle sign up
                          },
                          child: const Text('Create an account'),
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
        child: LayoutBuilder(builder: (context, constraints) {
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
        }),
      ),
    );
  }
}
