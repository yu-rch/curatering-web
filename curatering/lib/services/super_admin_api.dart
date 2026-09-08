import '../auth/roles.dart';
import '../models/action_log.dart';
import '../models/customer_feedback.dart';
import '../models/help_request.dart';
import '../models/user.dart';
import 'api_client.dart';

double _numAsDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int _numAsInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = '$value'.trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

DateTime? _dateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class SuperAdminDashboardSummary {
  const SuperAdminDashboardSummary({
    required this.asOf,
    required this.analytics,
    required this.userManagement,
    required this.sales,
  });

  final DateTime? asOf;
  final SuperAdminAnalyticsSummary analytics;
  final SuperAdminUserManagementSummary userManagement;
  final SuperAdminSalesSummary sales;

  factory SuperAdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    return SuperAdminDashboardSummary(
      asOf: _dateOrNull(json['asOf']),
      analytics: SuperAdminAnalyticsSummary.fromJson(
        Map<String, dynamic>.from((json['analytics'] as Map?) ?? const {}),
      ),
      userManagement: SuperAdminUserManagementSummary.fromJson(
        Map<String, dynamic>.from((json['userManagement'] as Map?) ?? const {}),
      ),
      sales: SuperAdminSalesSummary.fromJson(
        Map<String, dynamic>.from((json['sales'] as Map?) ?? const {}),
      ),
    );
  }
}

class SuperAdminAnalyticsSummary {
  const SuperAdminAnalyticsSummary({
    required this.website,
    required this.feedback,
    required this.helpRequests,
    required this.recentActions,
    required this.recentHelpRequests,
  });

  final WebsiteAnalyticsSummary website;
  final FeedbackAnalyticsSummary feedback;
  final HelpRequestAnalyticsSummary helpRequests;
  final List<SuperAdminActivityItem> recentActions;
  final List<SuperAdminActivityItem> recentHelpRequests;

  factory SuperAdminAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return SuperAdminAnalyticsSummary(
      website: WebsiteAnalyticsSummary.fromJson(
        Map<String, dynamic>.from((json['website'] as Map?) ?? const {}),
      ),
      feedback: FeedbackAnalyticsSummary.fromJson(
        Map<String, dynamic>.from((json['feedback'] as Map?) ?? const {}),
      ),
      helpRequests: HelpRequestAnalyticsSummary.fromJson(
        Map<String, dynamic>.from((json['helpRequests'] as Map?) ?? const {}),
      ),
      recentActions:
          ((json['recentActions'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (e) => SuperAdminActivityItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),
      recentHelpRequests:
          ((json['recentHelpRequests'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (e) => SuperAdminActivityItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),
    );
  }
}

class WebsiteAnalyticsSummary {
  const WebsiteAnalyticsSummary({
    required this.totalViews,
    required this.last30Views,
    required this.platformViews,
    required this.topPaths,
    required this.registrationsByPlatform,
  });

  final int totalViews;
  final int last30Views;
  final List<Map<String, dynamic>> platformViews;
  final List<Map<String, dynamic>> topPaths;
  final List<Map<String, dynamic>> registrationsByPlatform;

  factory WebsiteAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        ((json[key] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    return WebsiteAnalyticsSummary(
      totalViews: _numAsInt(json['totalViews']),
      last30Views: _numAsInt(json['last30Views']),
      platformViews: list('platformViews'),
      topPaths: list('topPaths'),
      registrationsByPlatform: list('registrationsByPlatform'),
    );
  }
}

class FeedbackAnalyticsSummary {
  const FeedbackAnalyticsSummary({
    required this.count,
    required this.averageStars,
    required this.complaints,
    required this.positive,
  });

  final int count;
  final double? averageStars;
  final int complaints;
  final int positive;

  factory FeedbackAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    final avg = json['averageStars'];
    return FeedbackAnalyticsSummary(
      count: _numAsInt(json['count']),
      averageStars: avg == null ? null : _numAsDouble(avg),
      complaints: _numAsInt(json['complaints']),
      positive: _numAsInt(json['positive']),
    );
  }
}

class HelpRequestAnalyticsSummary {
  const HelpRequestAnalyticsSummary({
    required this.total,
    required this.unresolved,
    required this.resolved,
    required this.last30,
  });

  final int total;
  final int unresolved;
  final int resolved;
  final int last30;

  factory HelpRequestAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return HelpRequestAnalyticsSummary(
      total: _numAsInt(json['total']),
      unresolved: _numAsInt(json['unresolved']),
      resolved: _numAsInt(json['resolved']),
      last30: _numAsInt(json['last30']),
    );
  }
}

class SuperAdminUserManagementSummary {
  const SuperAdminUserManagementSummary({
    required this.staff,
    required this.customers,
  });

  final StaffAccountSummary staff;
  final CustomerAccountSummary customers;

  factory SuperAdminUserManagementSummary.fromJson(Map<String, dynamic> json) {
    return SuperAdminUserManagementSummary(
      staff: StaffAccountSummary.fromJson(
        Map<String, dynamic>.from((json['staff'] as Map?) ?? const {}),
      ),
      customers: CustomerAccountSummary.fromJson(
        Map<String, dynamic>.from((json['customers'] as Map?) ?? const {}),
      ),
    );
  }
}

class StaffAccountSummary {
  const StaffAccountSummary({
    required this.total,
    required this.active,
    required this.archived,
    required this.roleCounts,
  });

  final int total;
  final int active;
  final int archived;
  final Map<String, int> roleCounts;

  factory StaffAccountSummary.fromJson(Map<String, dynamic> json) {
    final raw = Map<String, dynamic>.from(
      (json['roleCounts'] as Map?) ?? const {},
    );
    return StaffAccountSummary(
      total: _numAsInt(json['total']),
      active: _numAsInt(json['active']),
      archived: _numAsInt(json['archived']),
      roleCounts: raw.map((key, value) => MapEntry(key, _numAsInt(value))),
    );
  }
}

class CustomerAccountSummary {
  const CustomerAccountSummary({
    required this.total,
    required this.active,
    required this.archived,
    required this.newThisMonth,
  });

  final int total;
  final int active;
  final int archived;
  final int newThisMonth;

  factory CustomerAccountSummary.fromJson(Map<String, dynamic> json) {
    return CustomerAccountSummary(
      total: _numAsInt(json['total']),
      active: _numAsInt(json['active']),
      archived: _numAsInt(json['archived']),
      newThisMonth: _numAsInt(json['newThisMonth']),
    );
  }
}

class SuperAdminSalesSummary {
  const SuperAdminSalesSummary({
    required this.restaurant,
    required this.catering,
    required this.events,
    required this.combined,
  });

  final SalesMetricSummary restaurant;
  final SalesMetricSummary catering;
  final SalesMetricSummary events;
  final SalesMetricSummary combined;

  factory SuperAdminSalesSummary.fromJson(Map<String, dynamic> json) {
    SalesMetricSummary metric(String key) => SalesMetricSummary.fromJson(
      Map<String, dynamic>.from((json[key] as Map?) ?? const {}),
    );
    return SuperAdminSalesSummary(
      restaurant: metric('restaurant'),
      catering: metric('catering'),
      events: metric('events'),
      combined: metric('combined'),
    );
  }
}

class SalesMetricSummary {
  const SalesMetricSummary({
    required this.totalSales,
    required this.monthSales,
    required this.yearSales,
    required this.orders,
    required this.completed,
    required this.pending,
  });

  final double totalSales;
  final double monthSales;
  final double yearSales;
  final int orders;
  final int completed;
  final int pending;

  factory SalesMetricSummary.fromJson(Map<String, dynamic> json) {
    return SalesMetricSummary(
      totalSales: _numAsDouble(json['totalSales']),
      monthSales: _numAsDouble(json['monthSales']),
      yearSales: _numAsDouble(json['yearSales']),
      orders: _numAsInt(json['orders']),
      completed: _numAsInt(json['completed']),
      pending: _numAsInt(json['pending']),
    );
  }
}

class SuperAdminActivityItem {
  const SuperAdminActivityItem({
    required this.id,
    required this.userName,
    required this.feature,
    required this.action,
    this.problem = '',
    this.status = '',
    this.createdAt,
  });

  final String id;
  final String userName;
  final String feature;
  final String action;
  final String problem;
  final String status;
  final DateTime? createdAt;

  factory SuperAdminActivityItem.fromJson(Map<String, dynamic> json) {
    return SuperAdminActivityItem(
      id: (json['id'] ?? '').toString(),
      userName: (json['userName'] ?? '').toString(),
      feature: (json['feature'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      problem: (json['problem'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: _dateOrNull(json['createdAt']),
    );
  }
}

class SuperAdminTodoDto {
  const SuperAdminTodoDto({
    required this.id,
    required this.title,
    required this.notes,
    required this.completed,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String notes;
  final bool completed;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SuperAdminTodoDto.fromJson(Map<String, dynamic> json) {
    return SuperAdminTodoDto(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      completed: json['completed'] == true,
      sortOrder: _numAsInt(json['sortOrder']),
      createdAt: _dateOrNull(json['createdAt']),
      updatedAt: _dateOrNull(json['updatedAt']),
    );
  }
}

class SuperAdminApi {
  SuperAdminApi._();

  static final SuperAdminApi instance = SuperAdminApi._();

  Future<SuperAdminDashboardSummary> getDashboardSummary({
    String range = '30d',
  }) async {
    final decoded = await ApiClient.instance.getJson(
      '/api/super-admin/dashboard/summary',
      queryParameters: {'range': range},
      useCache: false,
    );
    return SuperAdminDashboardSummary.fromJson(decoded);
  }

  Future<List<SuperAdminTodoDto>> listTodos() async {
    final decoded = await ApiClient.instance.getJson(
      '/api/super-admin/todos',
      useCache: false,
    );
    final raw = decoded['todos'];
    if (raw is! List) return const <SuperAdminTodoDto>[];
    return raw
        .whereType<Map>()
        .map((e) => SuperAdminTodoDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SuperAdminTodoDto> createTodo({
    required String title,
    String notes = '',
  }) async {
    final decoded = await ApiClient.instance.postJson(
      '/api/super-admin/todos',
      body: {'title': title, 'notes': notes},
    );
    return SuperAdminTodoDto.fromJson(
      Map<String, dynamic>.from(decoded['todo'] as Map),
    );
  }

  Future<SuperAdminTodoDto> updateTodo({
    required String todoId,
    String? title,
    String? notes,
    bool? completed,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (completed != null) 'completed': completed,
    };
    final decoded = await ApiClient.instance.patchJson(
      '/api/super-admin/todos/$todoId',
      body: body,
    );
    return SuperAdminTodoDto.fromJson(
      Map<String, dynamic>.from(decoded['todo'] as Map),
    );
  }

  Future<void> deleteTodo({required String todoId}) async {
    await ApiClient.instance.delete('/api/super-admin/todos/$todoId');
  }

  Future<List<UserDto>> listUsers({
    String? search,
    String? role,
    bool? archived,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty)
      query['search'] = search.trim();
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
        archived: _asBool(um['archived']),
        pagePermissions:
            permRaw is Map<String, dynamic>
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
    String? superAdminPassword,
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
        if (superAdminPassword != null)
          'superAdminPassword': superAdminPassword,
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
    String? superAdminPassword,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users/$userId',
      body: {
        'fullName': fullName,
        'role': role,
        'birthday': birthday,
        'contactNumber': contactNumber,
        'employmentType': employmentType,
        if (superAdminPassword != null)
          'superAdminPassword': superAdminPassword,
      },
    );
  }

  Future<void> setUserArchived({
    required String userId,
    required bool archived,
    String? superAdminPassword,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/users/$userId/archive',
      body: {
        'archived': archived,
        if (superAdminPassword != null)
          'superAdminPassword': superAdminPassword,
      },
    );
  }

  Future<List<HelpRequestDto>> listHelpRequests({
    String? search,
    String? status,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty)
      query['search'] = search.trim();
    if (status != null && status.trim().isNotEmpty)
      query['status'] = status.trim();

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
        resolutionNotes: (r['resolutionNotes'] ?? '').toString(),
      );
    }).toList();
  }

  Future<void> resolveHelpRequest({
    required String requestId,
    String? resolutionNotes,
  }) async {
    await ApiClient.instance.postJson(
      '/api/super-admin/help-requests/$requestId/resolve',
      body: {
        if (resolutionNotes != null && resolutionNotes.trim().isNotEmpty)
          'resolutionNotes': resolutionNotes.trim(),
      },
    );
  }

  Future<List<ActionLogDto>> listActionLogs({String? search}) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty)
      query['search'] = search.trim();

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
    final decoded = await ApiClient.instance.getJson(
      '/api/super-admin/role-limits',
    );
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

  Future<List<CustomerFeedbackDto>> listCustomerFeedback({
    String? search,
  }) async {
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
        .map(
          (r) =>
              CustomerFeedbackDto.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<CustomerFeedbackAnalysis> analyzeCustomerFeedback({
    String? search,
  }) async {
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
