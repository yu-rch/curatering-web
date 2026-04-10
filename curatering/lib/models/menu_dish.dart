class MenuDish {
  final String id;
  final String name;
  final String price;
  final List<String> paxOptions;
  final String? imageBase64;
  final String category;
  final List<String> sauces;
  final bool archived;
  final DateTime? archivedAt;

  const MenuDish({
    required this.id,
    required this.name,
    required this.price,
    required this.paxOptions,
    this.imageBase64,
    this.category = 'catering',
    this.sauces = const [],
    this.archived = false,
    this.archivedAt,
  });

  MenuDish copyWith({
    String? id,
    String? name,
    String? price,
    List<String>? paxOptions,
    String? imageBase64,
    String? category,
    List<String>? sauces,
    bool? archived,
    DateTime? archivedAt,
  }) {
    return MenuDish(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      paxOptions: paxOptions ?? this.paxOptions,
      imageBase64: imageBase64 ?? this.imageBase64,
      category: category ?? this.category,
      sauces: sauces ?? this.sauces,
      archived: archived ?? this.archived,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}

