import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'antd_buttons.dart';
import 'antd_dialog.dart';

/// Modal loading indicator (non-dismissible).
///
/// When awaited, completes after the loader is **visible** — not when it closes.
/// Call [hideBlockingLoadingDialog] when work finishes.
Future<void> showBlockingLoadingDialog(
  BuildContext context, {
  required String message,
}) async {
  if (!context.mounted) return;
  // Must not return showDialog's Future — that completes only on Navigator.pop.
  showDialog<void>(
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
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(Duration.zero);
}

void hideBlockingLoadingDialog(BuildContext context) {
  if (!context.mounted) return;
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) {
    nav.pop();
  }
}

/// Shows loader → runs [task] → hides loader. Safe to await end-to-end.
Future<T?> runWithBlockingLoadingDialog<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() task,
}) async {
  if (!context.mounted) return null;
  await showBlockingLoadingDialog(context, message: message);
  try {
    return await task();
  } finally {
    hideBlockingLoadingDialog(context);
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
