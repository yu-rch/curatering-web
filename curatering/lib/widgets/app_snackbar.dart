import 'package:flutter/material.dart';

/// Consistent floating snackbars (rounded, icon, readable contrast).
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  final theme = Theme.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final bg =
      error ? const Color(0xFFB3261E) : const Color(0xFF1E1E1E);
  final fg = Colors.white;
  final ic = icon ?? (error ? Icons.error_outline : Icons.check_circle_outline);

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(ic, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ) ??
                  TextStyle(color: fg, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      duration: duration,
    ),
  );
}
