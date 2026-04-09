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
      body: {'email': email, 'password': password},
    );

    ///print('Auth API response: $decoded');
    ///print('Response type: ${decoded.runtimeType}');

    final token = decoded['token'] as String;
    final userMap = decoded['user'] as Map<String, dynamic>;
    
    // print('User map from server: $userMap');
    // print('isVerified field: ${userMap['isVerified']}');
    // print('is_verified field: ${userMap['is_verified']}');
    // print('All userMap keys: ${userMap.keys.toList()}');

    final permRaw = userMap['pagePermissions'];
    final user = UserDto(
      id: userMap['id'].toString(),
      email: userMap['email'] as String,
      fullName: userMap['fullName'] as String? ?? userMap['full_name'] as String,
      role: roleFromString(userMap['role'] as String),
      archived: (userMap['archived'] ?? false) as bool,
      isVerified: (userMap['isVerified'] ?? userMap['is_verified'] ?? false) as bool,
      pagePermissions: permRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(permRaw)
          : (permRaw is Map
                ? Map<String, dynamic>.from(
                    permRaw.map((k, v) => MapEntry(k.toString(), v)),
                  )
                : null),
    );

    // print('Created UserDto with isVerified: ${user.isVerified}');
    // print('Created UserDto with role: ${user.role}');

    return LoginResponse(token: token, user: user);
  }

  Future<UserProfile> me() async {
    final decoded = await ApiClient.instance.getJson('/api/auth/me');
    final userMap = decoded['user'] as Map<String, dynamic>;
    final permRaw = userMap['pagePermissions'];

    return UserProfile(
      id: userMap['id'].toString(),
      email: userMap['email'] as String,
      fullName: userMap['full_name'] as String,
      role: roleFromString(userMap['role'] as String),
      isVerified: (userMap['isVerified'] ?? userMap['is_verified'] ?? false) as bool,
      pagePermissions: permRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(permRaw)
          : (permRaw is Map
                ? Map<String, dynamic>.from(
                    permRaw.map((k, v) => MapEntry(k.toString(), v)),
                  )
                : null),
    );
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    await ApiClient.instance.postJson(
      '/api/auth/verify-otp',
      body: {'email': email, 'otp': otp},
    );
  }
}
