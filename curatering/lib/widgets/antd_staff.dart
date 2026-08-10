import 'package:flutter/material.dart';

import 'antd_tokens.dart';

class AntdPage extends StatelessWidget {
  const AntdPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AntdTokens.pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            elevation: 0,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: AntdPageHeader(
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class AntdPageHeader extends StatelessWidget {
  const AntdPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AntdTokens.valueDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AntdTokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AntdCard extends StatelessWidget {
  const AntdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AntdTokens.cardBg,
        border: Border.all(color: AntdTokens.borderSubtle),
        borderRadius: BorderRadius.circular(AntdTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AntdToolbar extends StatelessWidget {
  const AntdToolbar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(12),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AntdCard(
      padding: padding,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class AntdSearchInput extends StatelessWidget {
  const AntdSearchInput({
    super.key,
    required this.controller,
    this.hintText = 'Search',
    this.width = 280,
    this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final double width;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AntdTokens.valueDark),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AntdTokens.labelMuted,
          ),
          suffixIcon:
              controller.text.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 17),
                    onPressed: onClear,
                  ),
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AntdTokens.labelMuted,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
            borderSide: const BorderSide(color: AntdTokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
            borderSide: const BorderSide(color: AntdTokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
            borderSide: const BorderSide(color: AntdTokens.blue, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class AntdSelect<T> extends StatelessWidget {
  const AntdSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.width = 220,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
            borderSide: const BorderSide(color: AntdTokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
            borderSide: const BorderSide(color: AntdTokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AntdTokens.radiusSm),
            borderSide: const BorderSide(color: AntdTokens.blue, width: 1.4),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class AntdStatusTag extends StatelessWidget {
  const AntdStatusTag({
    super.key,
    required this.label,
    this.color = AntdTokens.blue,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AntdEmptyState extends StatelessWidget {
  const AntdEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AntdTokens.labelMuted, size: 44),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AntdTokens.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class AntdLoadingState extends StatelessWidget {
  const AntdLoadingState({super.key, this.message = 'Loading...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            color: AntdTokens.brandPrimary,
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AntdTokens.labelMuted)),
        ],
      ),
    );
  }
}
