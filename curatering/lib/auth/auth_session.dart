import 'package:flutter/foundation.dart';

import '../services/auth_api.dart';
import 'roles.dart';

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final Role role;
  final bool isVerified;

  /// When empty or null, all sidebar pages are allowed (for manager/supervisor).
  final Map<String, dynamic>? pagePermissions;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.isVerified = false,
    this.pagePermissions,
  });
}

class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  final ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(
    null,
  );

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

  void clearSession() {
    clear();
  }

  /// Reload profile + page permissions from the API (staff/supervisor/manager).
  Future<void> refreshFromServer() async {
    if (!hasToken) return;
    final profile = await AuthApi.instance.me();
    final existing = currentUser.value;
    if (existing == null) {
      currentUser.value = profile;
      return;
    }
    currentUser.value = UserProfile(
      id: profile.id,
      email: profile.email,
      fullName: profile.fullName,
      role: profile.role,
      isVerified: profile.isVerified,
      pagePermissions: profile.pagePermissions,
    );
  }

  void updatePagePermissions(Map<String, dynamic>? permissions) {
    final u = currentUser.value;
    if (u == null) return;
    currentUser.value = UserProfile(
      id: u.id,
      email: u.email,
      fullName: u.fullName,
      role: u.role,
      isVerified: u.isVerified,
      pagePermissions: permissions == null
          ? null
          : Map<String, dynamic>.from(permissions),
    );
  }

  Role? get currentRole => currentUser.value?.role;

  bool get hasToken => _token != null && _token!.isNotEmpty;
}
