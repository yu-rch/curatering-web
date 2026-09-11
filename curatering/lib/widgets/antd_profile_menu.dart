import 'package:flutter/material.dart';

import 'antd_tokens.dart';

/// One row in [AntdProfileMenu] (header, normal action, or destructive).
class AntdProfileMenuItem {
  const AntdProfileMenuItem.header(this.label)
    : id = '__header__',
      icon = Icons.person_outline,
      onSelected = null,
      destructive = false,
      dividerBefore = false,
      isHeader = true;

  const AntdProfileMenuItem.action({
    required this.id,
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
    this.dividerBefore = false,
  }) : isHeader = false;

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onSelected;
  final bool destructive;
  final bool dividerBefore;
  final bool isHeader;
}

/// Profile / account dropdown: dark panel, blue icons, red destructive row.
/// Trigger blends into dark top bars (transparent fill, white label).
class AntdProfileMenu extends StatelessWidget {
  const AntdProfileMenu({
    super.key,
    required this.triggerLabel,
    this.leading,
    required this.items,
    this.compact = false,
    this.triggerBackgroundColor,
    this.triggerForegroundColor = Colors.white,
  });

  final String triggerLabel;
  final Widget? leading;
  final List<AntdProfileMenuItem> items;
  final bool compact;

  /// When null, trigger background is transparent (inherits top bar color).
  final Color? triggerBackgroundColor;

  final Color triggerForegroundColor;

  @override
  Widget build(BuildContext context) {
    final entries = <PopupMenuEntry<String>>[];
    for (final item in items) {
      if (item.dividerBefore) {
        entries.add(const PopupMenuDivider());
      }
      if (item.isHeader) {
        entries.add(
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            value: item.id,
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        );
        continue;
      }
      entries.add(
        PopupMenuItem<String>(
          value: item.id,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: item.destructive ? AntdTokens.error : AntdTokens.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.destructive ? AntdTokens.error : Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: AntdTokens.menuBg,
          elevation: 12,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AntdTokens.borderSubtle),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 8),
        tooltip: 'Account menu',
        onSelected: (id) {
          for (final item in items) {
            if (!item.isHeader && item.id == id) {
              item.onSelected?.call();
              break;
            }
          }
        },
        itemBuilder: (_) => entries,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: 8,
          ),  
          decoration: BoxDecoration(
            color: triggerBackgroundColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  triggerLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: triggerForegroundColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more,
                color: triggerForegroundColor.withValues(alpha: 0.85),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
