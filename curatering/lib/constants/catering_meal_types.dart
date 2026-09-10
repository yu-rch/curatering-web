/// Standard catering meal types stored in `menu_dishes.meal_type`.
const List<String> kCateringMealTypes = [
  'appetizer',
  'main',
  'sides',
  'pasta',
  'drinks',
];

String normalizeCateringMealType(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return '';
  if (kCateringMealTypes.contains(value)) return value;

  switch (value) {
    case 'appetizers':
      return 'appetizer';
    case 'main course':
    case 'main courses':
    case 'mains':
      return 'main';
    case 'side':
    case 'side dish':
    case 'side dishes':
      return 'sides';
    case 'drink':
    case 'beverage':
    case 'beverages':
      return 'drinks';
    // Restaurant leftover values must not pollute catering filters.
    case 'other':
    case 'others':
      return '';
    default:
      return value;
  }
}

String mealTypeDisplayLabel(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;
  return v
      .split(RegExp(r'\s+'))
      .map(
        (word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

bool cateringMealTypeMatches(String dishMealType, String filter) {
  if (filter.trim().isEmpty) return true;
  return normalizeCateringMealType(dishMealType) ==
      normalizeCateringMealType(filter);
}
