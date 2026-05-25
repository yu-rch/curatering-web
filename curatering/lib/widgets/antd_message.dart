import 'package:flutter/material.dart';

import 'antd_tokens.dart';

enum AntdMessageType { success, error, warning }

/// Bottom-right transient feedback (Ant Design notification style).
void showAntdMessage(
  BuildContext context,
  String message, {
  AntdMessageType type = AntdMessageType.success,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            _StatusDot(type: type),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AntdTokens.messageBarBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        duration: duration,
      ),
    );
    return;
  }

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return Positioned(
        right: 24,
        bottom: MediaQuery.paddingOf(ctx).bottom + 24,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
          child: Material(
            color: AntdTokens.messageBarBg,
            elevation: 8,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusDot(type: type),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
  );

  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    entry.remove();
  });
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.type});

  final AntdMessageType type;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Widget icon;
    switch (type) {
      case AntdMessageType.error:
        bg = AntdTokens.error;
        icon = const Icon(Icons.close, size: 14, color: Colors.white);
        break;
      case AntdMessageType.warning:
        bg = AntdTokens.warning;
        icon = const Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            height: 1,
          ),
        );
        break;
      case AntdMessageType.success:
        bg = AntdTokens.success;
        icon = const Icon(Icons.check, size: 16, color: Colors.black87);
        break;
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: icon,
    );
  }
}
