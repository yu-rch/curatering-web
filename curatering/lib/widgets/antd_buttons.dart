import 'package:flutter/material.dart';

import 'antd_tokens.dart';

/// Outlined cancel (light modal footer).
class AntdCancelButton extends StatelessWidget {
  const AntdCancelButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AntdTokens.brandOnPrimary,
        side: const BorderSide(color: AntdTokens.borderSubtle),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label),
    );
  }
}

/// Primary action — brand gold background, dark text.
class AntdPrimaryButton extends StatelessWidget {
  const AntdPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AntdTokens.brandPrimary,
        foregroundColor: AntdTokens.brandOnPrimary,
        disabledBackgroundColor: AntdTokens.brandPrimary.withValues(alpha: 0.5),
        disabledForegroundColor: AntdTokens.brandOnPrimary.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child:
          loading
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AntdTokens.brandOnPrimary,
                ),
              )
              : Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
    );
  }
}
