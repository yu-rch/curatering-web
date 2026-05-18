import '../auth/roles.dart';
import '../models/action_log.dart';
import '../models/customer_feedback.dart';
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
      final um = u as Map<String, dynamic>;
      final permRaw = um['pagePermissions'];
      return UserDto(
        id: um['id'].toString(),
        email: um['email'] as String,
        fullName: um['fullName'] as String,
        role: roleFromString(um['role'] as String),
        archived: (um['archived'] ?? false) as bool,
        pagePermissions: permRaw is Map<String, dynamic>
            ? Map<String, dynamic>.from(permRaw)
            : (permRaw is Map
                ? Map<String, dynamic>.from(
                    permRaw.map((k, v) => MapEntry(k.toString(), v)),
                  )
                : null),
        birthday: um['birthday'] as String?,
        contactNumber: um['contactNumber'] as String?,
        employmentType: um['employmentType'] as String?,
      );
    }).toList();
  }

  Future<void> updateUserPagePermissions({
    required String userId,
    required Map<String, dynamic> pagePermissions,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users/$userId/page-permissions',
      body: {'pagePermissions': pagePermissions},
    );
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? birthday,
    String? contactNumber,
    String? employmentType,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users',
      body: {
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role,
        'birthday': birthday,
        'contactNumber': contactNumber,
        'employmentType': employmentType,
      },
    );
  }

  Future<void> updateUser({
    required String userId,
    required String fullName,
    required String role,
    String? birthday,
    String? contactNumber,
    String? employmentType,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users/$userId',
      body: {
        'fullName': fullName,
        'role': role,
        'birthday': birthday,
        'contactNumber': contactNumber,
        'employmentType': employmentType,
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

  /// Keys: `admin`, `manager`, `supervisor`, `cashier`. Values are positive ints
  /// or absent / null for unlimited (server merges with existing).
  Future<Map<String, dynamic>> getRoleLimits() async {
    final decoded = await ApiClient.instance.getJson('/api/super-admin/role-limits');
    final raw = decoded['limits'];
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  Future<void> putRoleLimits(Map<String, dynamic> limits) async {
    await ApiClient.instance.putJson(
      '/api/super-admin/role-limits',
      body: {'limits': limits},
    );
  }

  Future<List<CustomerFeedbackDto>> listCustomerFeedback({String? search}) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final decoded = await ApiClient.instance.getJson(
      '/api/super-admin/customer-feedback',
      queryParameters: query.isEmpty ? null : query,
    );
    final raw = decoded['feedback'];
    if (raw is! List) return const <CustomerFeedbackDto>[];

    return raw
        .map((r) => CustomerFeedbackDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<CustomerFeedbackAnalysis> analyzeCustomerFeedback({String? search}) async {
    final body = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      body['search'] = search.trim();
    }

    final decoded = await ApiClient.instance.postJson(
      '/api/super-admin/customer-feedback/analyze',
      body: body,
    );
    final raw = decoded['analysis'];
    if (raw is! Map) {
      throw StateError('Invalid analysis response');
    }
    return CustomerFeedbackAnalysis.fromJson(Map<String, dynamic>.from(raw));
  }
}

