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

class AntdSecondaryButton extends StatelessWidget {
  const AntdSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 8)],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AntdTokens.valueDark,
        side: const BorderSide(color: AntdTokens.border),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
        ),
      ),
      child: child,
    );
  }
}

class AntdDangerButton extends StatelessWidget {
  const AntdDangerButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 8)],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AntdTokens.error,
        side: const BorderSide(color: AntdTokens.error),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
        ),
      ),
      child: child,
    );
  }
}

/// Primary action — brand gold background, dark text.
class AntdPrimaryButton extends StatelessWidget {
  const AntdPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
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
        disabledForegroundColor: AntdTokens.brandOnPrimary.withValues(
          alpha: 0.6,
        ),
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
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
    );
  }
}

class AntdIconActionButton extends StatelessWidget {
  const AntdIconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AntdTokens.error : AntdTokens.valueDark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AntdTokens.border),
            borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null ? AntdTokens.labelMuted : color,
          ),
        ),
      ),
    );
  }
}
