import 'package:flutter/material.dart';

import 'antd_dialog.dart';

/// POS sidebar logout confirmation — returns true when the user confirms.
Future<bool?> confirmLogout(BuildContext context) {
  return DialogOpenGuard.runOnce<bool>(
    () => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
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
    ),
    key: 'confirm-logout',
  );
}
