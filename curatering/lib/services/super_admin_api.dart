import '../auth/roles.dart';
import '../models/action_log.dart';
import '../models/help_request.dart';
import '../models/user.dart';
import 'api_client.dart';

class SuperAdminApi {
  SuperAdminApi._();

  static final SuperAdminApi instance = SuperAdminApi._();

  Future<List<UserDto>> listUsers({String? search, String? role, bool? archived}) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (role != null && role.trim().isNotEmpty) query['role'] = role.trim();
    if (archived != null) query['archived'] = archived ? 'true' : 'false';

    final decoded = await ApiClient.instance.getJson(
      '/api/super-admin/users',
      queryParameters: query.isEmpty ? null : query,
    );

    final usersRaw = decoded['users'];
    if (usersRaw is! List) return const <UserDto>[];

    return usersRaw.map((u) {
      return UserDto(
        id: u['id'].toString(),
        email: u['email'] as String,
        fullName: u['fullName'] as String,
        role: roleFromString(u['role'] as String),
        archived: (u['archived'] ?? false) as bool,
      );
    }).toList();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users',
      body: {
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role,
      },
    );
  }

  Future<void> updateUser({
    required String userId,
    required String fullName,
    required String role,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users/$userId',
      body: {
        'fullName': fullName,
        'role': role,
      },
    );
  }

  Future<void> setUserArchived({
    required String userId,
    required bool archived,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users/$userId/archive',
      body: {'archived': archived},
    );
  }

  Future<List<HelpRequestDto>> listHelpRequests({
    String? search,
    String? status,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (status != null && status.trim().isNotEmpty) query['status'] = status.trim();

    final decoded = await ApiClient.instance.getJson(
      '/api/super-admin/help-requests',
      queryParameters: query.isEmpty ? null : query,
    );
    final raw = decoded['helpRequests'];
    if (raw is! List) return const <HelpRequestDto>[];

    return raw.map((r) {
      return HelpRequestDto(
        id: r['id'].toString(),
        userName: r['userName'] as String,
        userId: r['userId'].toString(),
        feature: r['feature'] as String,
        problem: r['problem'] as String,
        request: r['request'] as String,
        createdAt: DateTime.parse(r['createdAt'] as String),
        status: helpRequestStatusFromString(r['status'] as String),
      );
    }).toList();
  }

  Future<void> resolveHelpRequest({required String requestId}) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/help-requests/$requestId/resolve',
    );
  }

  Future<List<ActionLogDto>> listActionLogs({String? search}) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    final decoded = await ApiClient.instance.getJson(
      '/api/super-admin/action-logs',
      queryParameters: query.isEmpty ? null : query,
    );
    final raw = decoded['actionLogs'];
    if (raw is! List) return const <ActionLogDto>[];

    return raw.map((r) {
      return ActionLogDto(
        id: r['id'].toString(),
        userName: r['userName'] as String,
        feature: (r['feature'] ?? '').toString(),
        action: r['action'] as String,
        createdAt: DateTime.parse(r['createdAt'] as String),
        other: (r['other'] ?? 'n/a').toString(),
      );
    }).toList();
  }
}

