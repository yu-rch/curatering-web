import 'package:flutter/material.dart';

import 'antd_buttons.dart';
import 'antd_tokens.dart';

/// Prevents stacking multiple dialogs from rapid re-clicks on action buttons.
class DialogOpenGuard {
  DialogOpenGuard._();
  static final Set<String> _openKeys = <String>{};

  static bool tryAcquire([String key = 'global']) {
    if (_openKeys.contains(key)) return false;
    _openKeys.add(key);
    return true;
  }

  static void release([String key = 'global']) {
    _openKeys.remove(key);
  }

  /// Clears all dialog locks (e.g. after abandoning a modal via navigation).
  static void clearAll() {
    _openKeys.clear();
  }

  /// Runs [open] only if [key] is free; releases when the future completes.
  static Future<T?> runOnce<T>(
    Future<T?> Function() open, {
    String key = 'global',
  }) async {
    if (!tryAcquire(key)) return null;
    try {
      return await open();
    } finally {
      release(key);
    }
  }
}

/// Light Ant Design modal (ref. responsive-width sample): white body, footer actions.
Future<T?> showAntdModal<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
  double maxWidth = 560,
  String? guardKey,
  /// When false, [body] is not wrapped in a scroll view (use for Expanded tables).
  bool scrollBody = true,
}) {
  final key = guardKey ?? 'antd-modal:${title.hashCode}';
  return DialogOpenGuard.runOnce<T>(
    () => showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        final maxBodyHeight = MediaQuery.sizeOf(ctx).height * 0.65;
        final paddedBody = Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: AntdTokens.valueDark,
              fontSize: 14,
              height: 1.45,
            ),
            child: body,
          ),
        );
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              color: AntdTokens.modalBg,
              elevation: 12,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AntdTokens.valueDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.close, color: Colors.grey.shade600),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxBodyHeight),
                    child: scrollBody
                        ? SingleChildScrollView(child: paddedBody)
                        : paddedBody,
                  ),
                  if (actions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    key: key,
  );
}

/// Dark Curatering success modal: `#1E1E1E` body, yellow OK, white title.
Future<void> showCurateringSuccessDialog({
  required BuildContext context,
  required String title,
  String? body,
  String okLabel = 'OK',
}) {
  return DialogOpenGuard.runOnce<void>(
    () => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: const Color(0xFF1E1E1E),
              elevation: 12,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body != null && body.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AntdTokens.brandPrimary,
                          foregroundColor: AntdTokens.brandOnPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          okLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
    key: 'curatering-success:$title',
  );
}

/// Standard OK / Cancel footer for [showAntdModal].
List<Widget> antdModalActions({
  required BuildContext context,
  VoidCallback? onCancel,
  VoidCallback? onOk,
  String cancelLabel = 'Cancel',
  String okLabel = 'OK',
  bool okLoading = false,
}) {
  return [
    AntdCancelButton(
      label: cancelLabel,
      onPressed: onCancel ?? () => Navigator.of(context).pop(),
    ),
    AntdPrimaryButton(
      label: okLabel,
      loading: okLoading,
      onPressed: onOk,
    ),
  ];
}
