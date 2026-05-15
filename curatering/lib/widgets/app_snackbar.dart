import 'package:flutter/material.dart';

import 'antd_message.dart';

/// Backwards-compatible wrapper — prefer [showAntdMessage] for new code.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  showAntdMessage(
    context,
    message,
    type: error ? AntdMessageType.error : AntdMessageType.success,
    duration: duration,
  );
}
