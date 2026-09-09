import 'package:flutter/material.dart';
import '../theme/customer_fonts.dart';

/// Centered Ant Design–inspired page hero used on Catering / Gallery / Restaurant.
class CustomerAntdPageHero extends StatelessWidget {
  const CustomerAntdPageHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.filters,
    this.titleFontSize = 28,
  });

  final String title;
  final String subtitle;
  final Widget? filters;
  final double titleFontSize;

  static const Color accentYellow = Color(0xFFFFC024);
  static const Color titleColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final sub = subtitle.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.trim().isEmpty ? title : title.toUpperCase(),
          textAlign: TextAlign.center,
          style: CustomerFonts.poppins(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: 0.4,
          ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: accentYellow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: titleColor,
              ),
            ),
          ),
        ],
        if (filters != null) ...[
          const SizedBox(height: 16),
          filters!,
        ],
      ],
    );
  }
}

/// Ant Design–like outlined select with floating label.
class CustomerAntdFilterSelect<T> extends StatelessWidget {
  const CustomerAntdFilterSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 220,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: CustomerAntdPageHero.accentYellow, width: 1.5),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Yellow checkable category chips matching the Catering Menu filter row.
class CustomerAntdFilterChips extends StatelessWidget {
  const CustomerAntdFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allLabel = 'All',
  });

  /// Map of value → display label. Empty-string key is treated as "All".
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[
      MapEntry('', allLabel),
      ...options.entries,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final e in entries)
          FilterChip(
            showCheckmark: true,
            label: Text(e.value, style: const TextStyle(fontSize: 12)),
            selected: selected.trim().isEmpty
                ? e.key.isEmpty
                : selected.toLowerCase() == e.key.toLowerCase(),
            onSelected: (_) => onSelected(e.key),
            selectedColor: CustomerAntdPageHero.accentYellow,
            checkmarkColor: CustomerAntdPageHero.titleColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: (selected.trim().isEmpty ? e.key.isEmpty : selected.toLowerCase() == e.key.toLowerCase())
                  ? CustomerAntdPageHero.accentYellow
                  : Colors.grey.shade300,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
