import '../auth/roles.dart';

class UserDto {
  final String id;
  final String email;
  final String fullName;
  final Role role;
  final bool archived;
  final bool isVerified;
  final Map<String, dynamic>? pagePermissions;

  const UserDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.archived,
    this.isVerified = false,
    this.pagePermissions,
  });
}

