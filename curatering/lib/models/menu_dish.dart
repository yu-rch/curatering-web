class MenuDish {
  final String id;
  final String name;
  final String price;
  final List<String> paxOptions;
  final String? imageBase64;
  final bool archived;
  final DateTime? archivedAt;

  const MenuDish({
    required this.id,
    required this.name,
    required this.price,
    required this.paxOptions,
    this.imageBase64,
    this.archived = false,
    this.archivedAt,
  });

  MenuDish copyWith({
    String? id,
    String? name,
    String? price,
    List<String>? paxOptions,
    String? imageBase64,
    bool? archived,
    DateTime? archivedAt,
  }) {
    return MenuDish(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      paxOptions: paxOptions ?? this.paxOptions,
      imageBase64: imageBase64 ?? this.imageBase64,
      archived: archived ?? this.archived,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}

