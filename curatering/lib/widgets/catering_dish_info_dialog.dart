import 'package:flutter/material.dart';

import '../models/menu_dish.dart';
import '../utils/image_cache.dart';

void showCateringDishInfoDialog(
  BuildContext context,
  MenuDish dish, {
  VoidCallback? onInquireNow,
  bool showInquireNow = true,
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
      final screenW = MediaQuery.sizeOf(ctx).width;
      final wide = screenW >= 700;
      final hasImage = dish.imageBase64?.isNotEmpty == true;

      Widget photo({required double height}) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child:
                hasImage
                    ? CachedBase64Image(
                      base64String: dish.imageBase64,
                      fit: BoxFit.cover,
                    )
                    : ColoredBox(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.restaurant_menu, size: 48),
                      ),
                    ),
          ),
        );
      }

      final details = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  dish.name.toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
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

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? 1100 : 520,
            maxHeight: wide ? 520 : 640,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wide)
                  SizedBox(
                    height: 400,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Photo on the left
                        Expanded(flex: 5, child: photo(height: 400)),
                        const SizedBox(width: 28),
                        // Descriptions / info on the right
                        Expanded(flex: 7, child: details),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        photo(height: 220),
                        const SizedBox(height: 16),
                        Expanded(child: details),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('CLOSE'),
                    ),
                    if (showInquireNow) ...[
                      const SizedBox(width: 8),
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
                  ],
                ),
              ],
            ),
          ),
        ),
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
