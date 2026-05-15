import 'package:flutter/material.dart';

/// Label + value pair for [AntdDescriptions].
class AntdDescriptionItem {
  const AntdDescriptionItem({
    required this.label,
    required this.value,
    this.span = 1,
  });

  final String label;
  final String value;
  /// Relative width when [column] columns are shown (e.g. 2 spans two columns).
  final int span;
}

/// Ant Design–style read-only grid: muted labels, bright values (dark theme).
class AntdDescriptions extends StatelessWidget {
  const AntdDescriptions({
    super.key,
    this.title,
    required this.items,
    this.column = 3,
    this.labelColor = const Color(0xFF8C8C8C),
    this.valueColor = Colors.white,
  });

  final String? title;
  final List<AntdDescriptionItem> items;
  final int column;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth;
            if (maxW <= 0) return const SizedBox.shrink();
            final col = column.clamp(1, 6);
            final cellW = maxW / col;
            return Wrap(
              spacing: 0,
              runSpacing: 14,
              children:
                  items.map((it) {
                    final w = cellW * it.span.clamp(1, col);
                    return SizedBox(
                      width: w,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${it.label} :',
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              it.value.isEmpty ? '—' : it.value,
                              style: TextStyle(
                                color: valueColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }
}
