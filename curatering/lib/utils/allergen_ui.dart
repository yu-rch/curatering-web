import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

const String kAllergenOthersChipLabel = 'Others';

Set<String> guestAllergensForSubmit(
  Set<String> selected, {
  String othersText = '',
}) {
  final out = Set<String>.from(selected)..remove(kAllergenOthersChipLabel);
  final custom = othersText.trim();
  if (custom.isNotEmpty) out.add(custom);
  return out;
}

Widget buildGuestAllergenSelector({
  required List<String> catalog,
  required Set<String> selected,
  required bool enabled,
  required ValueChanged<Set<String>> onChanged,
  bool showOthers = true,
  TextEditingController? othersController,
  ValueChanged<String>? onOthersTextChanged,
}) {
  final othersSelected =
      selected.contains(kAllergenOthersChipLabel) ||
      (othersController?.text.trim().isNotEmpty ?? false);
  final catalogNames =
      catalog
          .map((e) => e.trim())
          .where(
            (e) =>
                e.isNotEmpty &&
                e.toLowerCase() != kAllergenOthersChipLabel.toLowerCase(),
          )
          .toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Select all allergens your guests must avoid (optional).',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade800,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in catalogNames)
            FilterChip(
              label: Text(name, style: const TextStyle(fontSize: 12)),
              selected: selected.contains(name),
              onSelected:
                  enabled
                      ? (value) {
                        final next = Set<String>.from(selected);
                        value ? next.add(name) : next.remove(name);
                        onChanged(next);
                      }
                      : null,
            ),
          if (showOthers)
            FilterChip(
              label: const Text(
                kAllergenOthersChipLabel,
                style: TextStyle(fontSize: 12),
              ),
              selected: othersSelected,
              onSelected:
                  enabled
                      ? (value) {
                        final next = Set<String>.from(selected);
                        if (value) {
                          next.add(kAllergenOthersChipLabel);
                        } else {
                          next.remove(kAllergenOthersChipLabel);
                          othersController?.clear();
                          onOthersTextChanged?.call('');
                        }
                        onChanged(next);
                      }
                      : null,
            ),
        ],
      ),
      if (showOthers && othersSelected) ...[
        const SizedBox(height: 10),
        TextField(
          controller: othersController,
          enabled: enabled,
          onChanged: onOthersTextChanged,
          decoration: const InputDecoration(
            labelText: 'Specify other allergen(s)',
            hintText: 'e.g. sulfites, mustard',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 2,
        ),
      ],
    ],
  );
}

Widget managerThemeDesignImagePreview(
  Map<String, dynamic> themeDesign, {
  double height = 160,
}) {
  final image =
      '${themeDesign['image'] ?? themeDesign['imageBase64'] ?? themeDesign['output'] ?? ''}'
          .trim();
  final imageUrl =
      '${themeDesign['generatedImageUrl'] ?? themeDesign['imageUrl'] ?? themeDesign['url'] ?? ''}'
          .trim();
  if (image.isNotEmpty) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(image),
          height: height,
          fit: BoxFit.contain,
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
  if (imageUrl.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
  return Text(
    'No generated theme design image yet.',
    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
  );
}

Widget dishDetailSection(String title, String body) {
  if (body.trim().isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          body.trim(),
          style: TextStyle(
            height: 1.35,
            fontSize: 13,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    ),
  );
}

Widget dishDetailAllergenColumn(List<String> allergens) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Allergens',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      const SizedBox(height: 6),
      if (allergens.isEmpty)
        Text(
          'None listed',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        )
      else
        for (final allergen in allergens)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '• $allergen',
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
    ],
  );
}

Future<void> showMenuDishDetailDialog(
  BuildContext context, {
  required String dishName,
  String description = '',
  List<String> ingredients = const [],
  List<String> allergens = const [],
  String? imageBase64,
  String? lineNote,
}) {
  Widget? imageWidget;
  final raw = imageBase64?.trim();
  if (raw != null && raw.isNotEmpty) {
    try {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          Uint8List.fromList(base64Decode(raw)),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          cacheWidth: 240,
        ),
      );
    } catch (_) {
      imageWidget = null;
    }
  }

  return showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(
            dishName,
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
          ),
          content: SizedBox(
            width: math.min(MediaQuery.sizeOf(ctx).width * 0.92, 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageWidget != null) ...[
                    Center(child: imageWidget),
                    const SizedBox(height: 12),
                  ],
                  dishDetailSection('Description', description),
                  if (ingredients.isNotEmpty)
                    dishDetailSection('Ingredients', ingredients.join(', ')),
                  if (allergens.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    dishDetailAllergenColumn(allergens),
                  ],
                  dishDetailSection('Notes', lineNote ?? ''),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
  );
}
