import 'package:flutter/material.dart';

import 'antd_buttons.dart';
import 'antd_dialog.dart';

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
