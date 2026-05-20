import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/menu_dish.dart';

void showCateringDishInfoDialog(BuildContext context, MenuDish dish) {
  final desc = dish.publicDescription.trim();
  final allergens = dish.allergens.trim();
  final ingredients =
      dish.ingredients
          .where((ingredient) => ingredient.trim().isNotEmpty)
          .toList();

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(dish.name),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dish.imageBase64?.isNotEmpty == true) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.memory(
                        base64Decode(dish.imageBase64!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _detailBlock(
                  'Description',
                  desc.isEmpty ? 'No description yet.' : desc,
                ),
                _detailBlock(
                  'Ingredients',
                  ingredients.isEmpty
                      ? 'No ingredients listed.'
                      : ingredients.join(', '),
                ),
                _detailBlock(
                  'Allergens',
                  allergens.isEmpty ? 'None listed.' : allergens,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      );
    },
  );
}

Widget _detailBlock(String title, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: Colors.grey.shade800, height: 1.35),
        ),
      ],
    ),
  );
}
