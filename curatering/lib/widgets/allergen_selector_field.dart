import 'package:flutter/material.dart';

import '../services/allergen_presets_store.dart';
import 'antd_tokens.dart';

/// Common allergens (top list) plus "Other" with free text — serialized as comma-separated [AllergenSelectorField.value].
class AllergenSelectorField extends StatefulWidget {
  const AllergenSelectorField({
    super.key,
    required this.initialSerialized,
    required this.onChanged,
  });

  /// Comma-separated list from server / model.
  final String initialSerialized;
  final ValueChanged<String> onChanged;

  @override
  State<AllergenSelectorField> createState() => _AllergenSelectorFieldState();
}

class _AllergenSelectorFieldState extends State<AllergenSelectorField> {
  static const List<String> _basePreset = [
    'Milk / Dairy',
    'Eggs',
    'Fish',
    'Shellfish / Crustaceans',
    'Tree nuts',
    'Peanuts',
    'Wheat / Gluten',
    'Soy',
    'Sesame',
    'Mustard',
    'Celery',
    'Lupin',
    'Sulfites',
    'Molluscs',
    'Corn',
    'Garlic',
    'Onion',
    'Coconut',
    'Chocolate / Cocoa',
    'Caffeine',
  ];

  List<String> _preset = List.from(_basePreset);
  late Set<String> _selected;
  late TextEditingController _otherCtrl;
  bool _otherSelected = false;

  @override
  void initState() {
    super.initState();
    _otherCtrl = TextEditingController();
    _parseInitial();
    _loadCustomPresets();
  }

  Future<void> _loadCustomPresets() async {
    final custom = await AllergenPresetsStore.instance.load();
    if (!mounted) return;
    setState(() {
      _preset = [..._basePreset, ...custom.where((c) => !_basePreset.contains(c))];
      _parseInitial();
    });
  }

  void _parseInitial() {
    final parts =
        widget.initialSerialized
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    _selected = {};
    final otherParts = <String>[];
    for (final p in parts) {
      if (_preset.contains(p)) {
        _selected.add(p);
      } else {
        otherParts.add(p);
        _otherSelected = true;
      }
    }
    if (otherParts.isNotEmpty) {
      _otherCtrl.text = otherParts.join(', ');
    }
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String _serialize() {
    final out = _selected.toList()..sort();
    if (_otherSelected && _otherCtrl.text.trim().isNotEmpty) {
      out.add(_otherCtrl.text.trim());
    }
    return out.join(', ');
  }

  void _emit() {
    widget.onChanged(_serialize());
  }

  void _togglePreset(String label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
      _emit();
    });
  }

  @override
  Widget build(BuildContext context) {
    FilterChip chip(String label, bool selected, VoidCallback onTap) {
      return FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        showCheckmark: true,
        selectedColor: AntdTokens.brandPrimary.withValues(alpha: 0.2),
        checkmarkColor: AntdTokens.brandOnPrimary,
        side: BorderSide(
          color: selected ? AntdTokens.brandPrimary : AntdTokens.borderSubtle,
        ),
        labelStyle: TextStyle(
          color: selected ? AntdTokens.brandOnPrimary : AntdTokens.valueDark,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        onSelected: (_) => onTap(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._preset.map(
              (a) => chip(a, _selected.contains(a), () => _togglePreset(a)),
            ),
            chip('Other', _otherSelected, () {
              setState(() {
                _otherSelected = !_otherSelected;
                if (!_otherSelected) _otherCtrl.clear();
                _emit();
              });
            }),
          ],
        ),
        if (_otherSelected) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _otherCtrl,
            onChanged: (_) => _emit(),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe any allergens not listed above',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AntdTokens.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AntdTokens.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AntdTokens.blue, width: 2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
