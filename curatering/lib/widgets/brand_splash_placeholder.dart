import 'package:flutter/material.dart';

/// Full-screen black loader matching the HTML splash (avoids white flash).
class BrandSplashPlaceholder extends StatelessWidget {
  const BrandSplashPlaceholder({
    super.key,
    this.message,
    this.error = false,
  });

  final String? message;
  final bool error;

  static const Color bg = Color(0xFF000000);
  static const Color accent = Color(0xFFFFC024);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: ColoredBox(
        color: bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error)
                Text(
                  message ?? 'Failed to load.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                )
              else ...[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: accent,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
