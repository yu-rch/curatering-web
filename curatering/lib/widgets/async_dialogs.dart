import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'antd_buttons.dart';
import 'antd_dialog.dart';

/// Modal loading indicator (non-dismissible).
/// Prefer [runWithBlockingLoadingDialog] — do not `await` this before async work.
Future<void> showBlockingLoadingDialog(
  BuildContext context, {
  required String message,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
}

void hideBlockingLoadingDialog(BuildContext context) {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) {
    nav.pop();
  }
}

/// Shows a blocking loader, runs [task], then closes the loader (safe for network calls).
Future<T?> runWithBlockingLoadingDialog<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() task,
}) async {
  if (!context.mounted) return null;
  final nav = Navigator.of(context, rootNavigator: true);
  showBlockingLoadingDialog(context, message: message);
  await SchedulerBinding.instance.endOfFrame;
  try {
    return await task();
  } finally {
    if (nav.canPop()) {
      nav.pop();
    }
  }
}

/// Returns true when the user confirms.
Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showAntdModal<bool>(
    context: context,
    title: title,
    barrierDismissible: false,
    body: Text(message),
    actions: [
      AntdCancelButton(
        label: cancelLabel,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      destructive
          ? FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(confirmLabel),
            )
          : AntdPrimaryButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(context).pop(true),
            ),
    ],
  );
  return result == true;
}
