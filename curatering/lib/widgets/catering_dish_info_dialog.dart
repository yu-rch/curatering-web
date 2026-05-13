import 'package:flutter/material.dart';

import '../models/menu_dish.dart';

void showCateringDishInfoDialog(BuildContext context, MenuDish dish) {
  final desc = dish.publicDescription.trim();
  final allergens = dish.allergens.trim();

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(dish.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                desc.isEmpty ? 'No description yet.' : desc,
                style: TextStyle(color: Colors.grey.shade800, height: 1.35),
              ),
              const SizedBox(height: 16),
              const Text(
                'Allergens',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                allergens.isEmpty ? 'None listed.' : allergens,
                style: TextStyle(color: Colors.grey.shade800, height: 1.35),
              ),
            ],
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
