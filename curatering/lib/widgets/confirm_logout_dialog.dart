import 'package:flutter/material.dart';

/// Shows a confirmation dialog before logging out.
Future<bool> confirmLogout(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'Are you sure you want to log out of your account?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  return result == true;
}
