import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/user.dart';
import 'api_client.dart';

class LoginResponse {
  final String token;
  final UserDto user;

  const LoginResponse({required this.token, required this.user});
}

class AuthApi {
  AuthApi._();

  static final AuthApi instance = AuthApi._();

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final decoded = await ApiClient.instance.postJson(
      '/api/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final token = decoded['token'] as String;
    final userMap = decoded['user'] as Map<String, dynamic>;

    final user = UserDto(
      id: userMap['id'].toString(),
      email: userMap['email'] as String,
      fullName: userMap['fullName'] as String,
      role: roleFromString(userMap['role'] as String),
      archived: (userMap['archived'] ?? false) as bool,
    );

    return LoginResponse(token: token, user: user);
  }

  Future<UserProfile> me() async {
    final decoded = await ApiClient.instance.getJson('/api/auth/me');
    final userMap = decoded['user'] as Map<String, dynamic>;

    return UserProfile(
      id: userMap['id'].toString(),
      email: userMap['email'] as String,
      fullName: userMap['fullName'] as String,
      role: roleFromString(userMap['role'] as String),
    );
  }
}

