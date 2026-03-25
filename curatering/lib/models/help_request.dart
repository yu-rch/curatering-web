enum HelpRequestStatus {
  unresolved,
  resolved,
}

HelpRequestStatus helpRequestStatusFromString(String raw) {
  final normalized = raw.trim().toLowerCase();
  return switch (normalized) {
    'unresolved' => HelpRequestStatus.unresolved,
    'resolved' => HelpRequestStatus.resolved,
    _ => HelpRequestStatus.unresolved,
  };
}

String helpRequestStatusToString(HelpRequestStatus status) {
  return switch (status) {
    HelpRequestStatus.unresolved => 'unresolved',
    HelpRequestStatus.resolved => 'resolved',
  };
}

class HelpRequestDto {
  final String id;
  final String userName;
  final String userId;
  final String feature;
  final String problem;
  final String request;
  final DateTime createdAt;
  final HelpRequestStatus status;

  const HelpRequestDto({
    required this.id,
    required this.userName,
    required this.userId,
    required this.feature,
    required this.problem,
    required this.request,
    required this.createdAt,
    required this.status,
  });
}

