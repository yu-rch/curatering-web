import 'package:flutter/material.dart';

import '../models/menu_dish.dart';
import '../utils/image_cache.dart';

void showCateringDishInfoDialog(
  BuildContext context,
  MenuDish dish, {
  VoidCallback? onInquireNow,
}) {
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
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 520),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final hasImage = dish.imageBase64?.isNotEmpty == true;
              final image =
                  hasImage
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: wide ? 320 : 220,
                          width: double.infinity,
                          child: CachedBase64Image(
                            base64String: dish.imageBase64,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      : Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.restaurant_menu, size: 48),
                        ),
                      );
              final details = SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    image,
                    const SizedBox(height: 16),
                    Expanded(child: details),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: image),
                  const SizedBox(width: 22),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CLOSE'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onInquireNow != null) {
                onInquireNow();
              } else {
                Navigator.of(context).pushNamed('/inquire');
              }
            },
            child: const Text('INQUIRE NOW'),
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
