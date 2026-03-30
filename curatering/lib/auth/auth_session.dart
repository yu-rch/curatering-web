import 'package:flutter/foundation.dart';
import 'roles.dart';

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final Role role;
  /// When empty or null, all sidebar pages are allowed (for manager/supervisor).
  final Map<String, dynamic>? pagePermissions;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.pagePermissions,
  });
}

class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  final ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(null);

  // For demo purposes we keep the token in memory only.
  String? _token;
  String? get token => _token;

  void setSession({required String token, required UserProfile user}) {
    _token = token;
    currentUser.value = user;
    isLoggedIn.value = true;
  }

  void clear() {
    _token = null;
    currentUser.value = null;
    isLoggedIn.value = false;
  }

  Role? get currentRole => currentUser.value?.role;

  bool get hasToken => _token != null && _token!.isNotEmpty;
}

