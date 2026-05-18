import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ant Design–style label (bold) + optional red asterisk + outlined control + inline helper/error.
class AntdFieldShell extends StatelessWidget {
  const AntdFieldShell({
    super.key,
    required this.label,
    this.required = false,
    this.errorText,
    this.helperText,
    required this.child,
  });

  final String label;
  final bool required;
  final String? errorText;
  final String? helperText;
  final Widget child;

  static const Color _border = Color(0xFFD9D9D9);
  static const Color _error = Color(0xFFFF4D4F);

  @override
  Widget build(BuildContext context) {
    final hasErr = errorText != null && errorText!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF262626),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 2),
              const Text('*', style: TextStyle(color: _error, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: hasErr ? _error : _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: hasErr ? _error : _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: hasErr ? _error : const Color(0xFF1677FF), width: 1.5),
              ),
            ),
          ),
          child: child,
        ),
        if (hasErr) ...[
          const SizedBox(height: 4),
          Text(errorText!.trim(), style: const TextStyle(color: _error, fontSize: 12)),
        ] else if (helperText != null && helperText!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(helperText!.trim(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ],
    );
  }
}

/// Outlined text field with external label (use inside [AntdFieldShell] as `child`).
class AntdOutlineInput extends StatelessWidget {
  const AntdOutlineInput({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.readOnly = false,
    this.decoration = const InputDecoration(border: InputBorder.none, isDense: true),
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: Color(0xFF262626)),
      decoration: decoration.copyWith(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        counterText: '',
      ),
    );
  }
}

/// Tap-to-pick control with the same height as [AntdOutlineInput] inside [AntdFieldShell].
class AntdPickerInput extends StatelessWidget {
  const AntdPickerInput({
    super.key,
    required this.value,
    required this.hintText,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String hintText;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                empty ? hintText : value,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      empty ? Colors.grey.shade500 : const Color(0xFF262626),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, size: 18, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}
