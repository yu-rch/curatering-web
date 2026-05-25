class MenuDish {
  final String id;
  final String name;
  final String price;
  final double additionalChargeAmount;
  final List<String> paxOptions;
  final String? imageBase64;
  final String category;
  final List<String> sauces;
  final bool archived;
  final bool available;
  final DateTime? archivedAt;
  final List<String> ingredients;

  /// Legacy column; prefer [mealType] from `menu_dishes.meal_type`.
  final String type;

  /// Meal type (restaurant section or catering course) from `menu_dishes.meal_type`.
  final String mealType;

  /// [mealType] when set, otherwise legacy [type].
  String get effectiveMealType {
    final mt = mealType.trim();
    if (mt.isNotEmpty) return mt;
    return type.trim();
  }

  final List<String> setMenus; // Array of set names this dish belongs to
  /// Short description for the dish on the public catering menu (tap for details).
  final String publicDescription;
  final String allergens;

  const MenuDish({
    required this.id,
    required this.name,
    required this.price,
    this.additionalChargeAmount = 0,
    required this.paxOptions,
    this.imageBase64,
    this.category = 'catering',
    this.sauces = const [],
    this.archived = false,
    this.available = true,
    this.archivedAt,
    this.ingredients = const [],
    this.type = '',
    this.mealType = '',
    this.setMenus = const [],
    this.publicDescription = '',
    this.allergens = '',
  });

  MenuDish copyWith({
    String? id,
    String? name,
    String? price,
    double? additionalChargeAmount,
    List<String>? paxOptions,
    String? imageBase64,
    String? category,
    List<String>? sauces,
    bool? archived,
    bool? available,
    DateTime? archivedAt,
    List<String>? ingredients,
    String? type,
    String? mealType,
    List<String>? setMenus,
    String? publicDescription,
    String? allergens,
  }) {
    return MenuDish(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      additionalChargeAmount:
          additionalChargeAmount ?? this.additionalChargeAmount,
      paxOptions: paxOptions ?? this.paxOptions,
      imageBase64: imageBase64 ?? this.imageBase64,
      category: category ?? this.category,
      sauces: sauces ?? this.sauces,
      archived: archived ?? this.archived,
      available: available ?? this.available,
      archivedAt: archivedAt ?? this.archivedAt,
      ingredients: ingredients ?? this.ingredients,
      type: type ?? this.type,
      mealType: mealType ?? this.mealType,
      setMenus: setMenus ?? this.setMenus,
      publicDescription: publicDescription ?? this.publicDescription,
      allergens: allergens ?? this.allergens,
    );
  }
}
