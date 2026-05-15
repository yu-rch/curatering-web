import 'package:flutter/material.dart';

import 'antd_buttons.dart';
import 'antd_tokens.dart';

/// Light Ant Design modal (ref. responsive-width sample): white body, footer actions.
Future<T?> showAntdModal<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
  double maxWidth = 560,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
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
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: AntdTokens.valueDark,
                        fontSize: 14,
                        height: 1.45,
                      ),
                      child: body,
                    ),
                  ),
                ),
                if (actions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
