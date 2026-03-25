class ActionLogDto {
  final String id;
  final String userName;
  final String feature;
  final String action;
  final DateTime createdAt;
  final String other;

  const ActionLogDto({
    required this.id,
    required this.userName,
    required this.feature,
    required this.action,
    required this.createdAt,
    required this.other,
  });
}

