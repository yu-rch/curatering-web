import 'api_client.dart';

abstract final class AiTaskTypes {
  static const feedbackAnalysis = 'feedback_analysis';
  static const dashboardAnalysis = 'dashboard_analysis';
  static const dishTrends = 'dish_trends';
  static const eventPromptExpansion = 'event_prompt_expansion';
  static const healthCheck = 'health_check';
}

enum AiTaskState { idle, queued, processing, completed, failed }

class DashboardFilters {
  const DashboardFilters({
    this.start,
    this.end,
    this.aiRange = '7d',
    this.orderSource = 'ALL',
    this.businessSide = 'ALL',
    this.cateringStyle = 'ALL',
  });

  final DateTime? start;
  final DateTime? end;
  final String aiRange;
  final String orderSource;
  final String businessSide;
  final String cateringStyle;

  Map<String, String> toQuery() {
    final query = <String, String>{};
    if (start != null) query['start'] = _date(start!);
    if (end != null) query['end'] = _date(end!);
    if (orderSource != 'ALL') query['orderSource'] = orderSource;
    if (businessSide != 'ALL') query['businessSide'] = businessSide;
    if (cateringStyle != 'ALL') query['cateringStyle'] = cateringStyle;
    return query;
  }

  Map<String, dynamic> toAiJson() {
    return {
      'range': aiRange,
      'orderSource': orderSource,
      'businessSide': businessSide,
      'cateringStyle': cateringStyle,
    };
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class DashboardSummary {
  const DashboardSummary({
    required this.restaurant,
    required this.catering,
    required this.salesThisYear,
    required this.monthlySales,
  });

  final RestaurantDashboardMetrics restaurant;
  final CateringDashboardMetrics catering;
  final SalesYearBreakdown salesThisYear;
  final List<MonthlyDashboardSales> monthlySales;

  Map<String, dynamic> toJson() {
    return {
      'restaurant': restaurant.toJson(),
      'catering': catering.toJson(),
      'salesThisYear': salesThisYear.toJson(),
      'monthlySales': monthlySales.map((item) => item.toJson()).toList(),
    };
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      restaurant: RestaurantDashboardMetrics.fromJson(
        Map<String, dynamic>.from(json['restaurant'] as Map? ?? {}),
      ),
      catering: CateringDashboardMetrics.fromJson(
        Map<String, dynamic>.from(json['catering'] as Map? ?? {}),
      ),
      salesThisYear: SalesYearBreakdown.fromJson(
        Map<String, dynamic>.from(json['salesThisYear'] as Map? ?? {}),
      ),
      monthlySales:
          (json['monthlySales'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (e) => MonthlyDashboardSales.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),
    );
  }
}

class RestaurantDashboardMetrics {
  const RestaurantDashboardMetrics({
    required this.pendingConfirmations,
    required this.delivered,
    required this.cancelled,
    required this.salesToday,
    required this.salesThisYear,
    required this.feedback,
  });

  final int pendingConfirmations;
  final int delivered;
  final int cancelled;
  final double salesToday;
  final double salesThisYear;
  final FeedbackDashboardMetrics feedback;

  Map<String, dynamic> toJson() {
    return {
      'pendingConfirmations': pendingConfirmations,
      'delivered': delivered,
      'cancelled': cancelled,
      'salesToday': salesToday,
      'salesThisYear': salesThisYear,
      'feedback': feedback.toJson(),
    };
  }

  factory RestaurantDashboardMetrics.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return RestaurantDashboardMetrics(
      pendingConfirmations:
          (json['pendingConfirmations'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      salesToday: d(json['salesToday']),
      salesThisYear: d(json['salesThisYear']),
      feedback: FeedbackDashboardMetrics.fromJson(
        Map<String, dynamic>.from(json['feedback'] as Map? ?? {}),
      ),
    );
  }
}

class CateringDashboardMetrics {
  const CateringDashboardMetrics({
    required this.inquiriesThisMonth,
    required this.acceptedTransactions,
    required this.forDownPayment,
    required this.ongoing,
    required this.forFullPayment,
    required this.completed,
    required this.cancelled,
    required this.salesToday,
    required this.salesThisYear,
    required this.feedback,
  });

  final int inquiriesThisMonth;
  final int acceptedTransactions;
  final int forDownPayment;
  final int ongoing;
  final int forFullPayment;
  final int completed;
  final int cancelled;
  final double salesToday;
  final double salesThisYear;
  final FeedbackDashboardMetrics feedback;

  Map<String, dynamic> toJson() {
    return {
      'inquiriesThisMonth': inquiriesThisMonth,
      'acceptedTransactions': acceptedTransactions,
      'forDownPayment': forDownPayment,
      'ongoing': ongoing,
      'forFullPayment': forFullPayment,
      'completed': completed,
      'cancelled': cancelled,
      'salesToday': salesToday,
      'salesThisYear': salesThisYear,
      'feedback': feedback.toJson(),
    };
  }

  factory CateringDashboardMetrics.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return CateringDashboardMetrics(
      inquiriesThisMonth: (json['inquiriesThisMonth'] as num?)?.toInt() ?? 0,
      acceptedTransactions:
          (json['acceptedTransactions'] as num?)?.toInt() ?? 0,
      forDownPayment: (json['forDownPayment'] as num?)?.toInt() ?? 0,
      ongoing: (json['ongoing'] as num?)?.toInt() ?? 0,
      forFullPayment: (json['forFullPayment'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      salesToday: d(json['salesToday']),
      salesThisYear: d(json['salesThisYear']),
      feedback: FeedbackDashboardMetrics.fromJson(
        Map<String, dynamic>.from(json['feedback'] as Map? ?? {}),
      ),
    );
  }
}

class FeedbackDashboardMetrics {
  const FeedbackDashboardMetrics({
    required this.count,
    required this.averageStars,
    required this.positiveCount,
    required this.neutralCount,
    required this.negativeCount,
    required this.complaintCount,
  });

  final int count;
  final double averageStars;
  final int positiveCount;
  final int neutralCount;
  final int negativeCount;
  final int complaintCount;

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'averageStars': averageStars,
      'positiveCount': positiveCount,
      'neutralCount': neutralCount,
      'negativeCount': negativeCount,
      'complaintCount': complaintCount,
    };
  }

  factory FeedbackDashboardMetrics.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return FeedbackDashboardMetrics(
      count: i(json['count']),
      averageStars: d(json['averageStars']),
      positiveCount: i(json['positiveCount']),
      neutralCount: i(json['neutralCount']),
      negativeCount: i(json['negativeCount']),
      complaintCount: i(json['complaintCount']),
    );
  }
}

class SalesYearBreakdown {
  const SalesYearBreakdown({
    required this.restaurant,
    required this.catering,
    required this.all,
  });

  final double restaurant;
  final double catering;
  final double all;

  Map<String, dynamic> toJson() {
    return {'restaurant': restaurant, 'catering': catering, 'all': all};
  }

  factory SalesYearBreakdown.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return SalesYearBreakdown(
      restaurant: d(json['restaurant']),
      catering: d(json['catering']),
      all: d(json['all']),
    );
  }
}

class MonthlyDashboardSales {
  const MonthlyDashboardSales({
    required this.month,
    required this.restaurantSales,
    required this.cateringSales,
    required this.totalSales,
    required this.restaurantOrders,
    required this.cateringOrders,
    required this.totalOrders,
  });

  final int month;
  final double restaurantSales;
  final double cateringSales;
  final double totalSales;
  final int restaurantOrders;
  final int cateringOrders;
  final int totalOrders;

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'restaurantSales': restaurantSales,
      'cateringSales': cateringSales,
      'totalSales': totalSales,
      'restaurantOrders': restaurantOrders,
      'cateringOrders': cateringOrders,
      'totalOrders': totalOrders,
    };
  }

  factory MonthlyDashboardSales.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return MonthlyDashboardSales(
      month: i(json['month']),
      restaurantSales: d(json['restaurantSales']),
      cateringSales: d(json['cateringSales']),
      totalSales: d(json['totalSales']),
      restaurantOrders: i(json['restaurantOrders']),
      cateringOrders: i(json['cateringOrders']),
      totalOrders: i(json['totalOrders']),
    );
  }
}

class BusinessAlert {
  const BusinessAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.explanation,
  });

  final String type;
  final String severity;
  final String message;
  final String explanation;

  factory BusinessAlert.fromJson(Map<String, dynamic> json) {
    return BusinessAlert(
      type: '${json['type'] ?? 'alert'}',
      severity: '${json['severity'] ?? 'info'}',
      message: '${json['message'] ?? ''}'.trim(),
      explanation: '${json['explanation'] ?? ''}'.trim(),
    );
  }
}

typedef DashboardInsightAlert = BusinessAlert;
typedef DashboardAlert = BusinessAlert;

class DishTrend {
  const DishTrend({
    required this.dish,
    required this.orders,
    required this.revenue,
  });

  final String dish;
  final double orders;
  final double revenue;

  factory DishTrend.fromJson(Map<String, dynamic> json) {
    double d(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return DishTrend(
      dish: '${json['dish'] ?? json['name'] ?? ''}'.trim(),
      orders: d(json['orders'] ?? json['quantity'] ?? json['count']),
      revenue: d(json['revenue'] ?? json['sales']),
    );
  }
}

class DishTrendAnalysis {
  const DishTrendAnalysis({
    required this.topDishes,
    required this.summary,
    required this.popularDishes,
    required this.decliningDishes,
    required this.seasonalPatterns,
    required this.recommendations,
  });

  final List<DishTrend> topDishes;
  final String summary;
  final List<String> popularDishes;
  final List<String> decliningDishes;
  final List<String> seasonalPatterns;
  final List<String> recommendations;

  List<DishTrend> get revenueLeaders {
    final sorted = [...topDishes];
    sorted.sort((a, b) => b.revenue.compareTo(a.revenue));
    return sorted;
  }

  List<String> get trendingDishes =>
      popularDishes.isNotEmpty
          ? popularDishes
          : topDishes.take(5).map((item) => item.dish).toList();

  bool get isEmpty =>
      topDishes.isEmpty &&
      summary.isEmpty &&
      popularDishes.isEmpty &&
      decliningDishes.isEmpty &&
      recommendations.isEmpty;

  static List<String> _strings(dynamic raw) =>
      DashboardAiAnalysis._stringList(raw);

  factory DishTrendAnalysis.fromJson(Map<String, dynamic> json) {
    final aggregated = Map<String, dynamic>.from(
      json['aggregated'] as Map? ?? const {},
    );
    final analysis = Map<String, dynamic>.from(
      json['analysis'] as Map? ?? json['result'] as Map? ?? const {},
    );
    final topDishes =
        (aggregated['top_dishes'] as List? ??
                json['top_dishes'] as List? ??
                const [])
            .whereType<Map>()
            .map((item) => DishTrend.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.dish.isNotEmpty)
            .toList();
    return DishTrendAnalysis(
      topDishes: topDishes,
      summary: '${analysis['summary'] ?? json['summary'] ?? ''}'.trim(),
      popularDishes: _strings(analysis['popular_dishes']),
      decliningDishes: _strings(analysis['declining_dishes']),
      seasonalPatterns: _strings(analysis['seasonal_patterns']),
      recommendations: _strings(
        analysis['recommendations'] ?? json['recommendations'],
      ),
    );
  }
}

typedef DishTrendsResult = DishTrendAnalysis;

class AiHealthStatus {
  const AiHealthStatus({
    required this.gpuOnline,
    required this.nlpOnline,
    required this.sdxlOnline,
    required this.queueSize,
    required this.lastInferenceLatencyMs,
    required this.message,
    required this.model,
    required this.gpuName,
  });

  final bool? gpuOnline;
  final bool? nlpOnline;
  final bool? sdxlOnline;
  final int? queueSize;
  final double? lastInferenceLatencyMs;
  final String message;
  final String model;
  final String gpuName;

  factory AiHealthStatus.fromJson(Map<String, dynamic> json) {
    bool? boolValue(dynamic value) {
      if (value is bool) return value;
      final text = '$value'.trim().toLowerCase();
      if (text == 'true' || text == 'online' || text == 'healthy') return true;
      if (text == 'false' || text == 'offline' || text == 'unhealthy') {
        return false;
      }
      return null;
    }

    int? intValue(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    double? doubleValue(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value');
    }

    final services = Map<String, dynamic>.from(
      json['services'] as Map? ?? const {},
    );
    final status = '${json['status'] ?? ''}'.trim().toLowerCase();
    return AiHealthStatus(
      gpuOnline: boolValue(
        json['gpu_online'] ?? json['cuda'] ?? services['gpu'],
      ),
      nlpOnline:
          boolValue(json['nlp_online'] ?? services['nlp']) ??
          (status == 'success' || status == 'healthy' || status == 'online'),
      sdxlOnline: boolValue(json['sdxl_online'] ?? services['sdxl']),
      queueSize: intValue(
        json['queue_size'] ?? json['queueSize'] ?? json['jobs_queued'],
      ),
      lastInferenceLatencyMs: doubleValue(
        json['last_inference_latency_ms'] ??
            json['lastInferenceLatencyMs'] ??
            json['latency_ms'],
      ),
      message: '${json['message'] ?? ''}'.trim(),
      model: '${json['model'] ?? ''}'.trim(),
      gpuName: '${json['gpu'] ?? json['gpu_name'] ?? ''}'.trim(),
    );
  }
}

class DashboardAiAnalysis {
  const DashboardAiAnalysis({
    required this.id,
    required this.analysisType,
    required this.range,
    required this.filterKey,
    required this.filters,
    required this.summary,
    required this.explainability,
    required this.insights,
    required this.trends,
    required this.problems,
    required this.recommendations,
    required this.alerts,
    required this.createdAt,
  });

  final String id;
  final String analysisType;
  final String range;
  final String filterKey;
  final Map<String, dynamic> filters;
  final String summary;
  final List<String> explainability;
  final List<String> insights;
  final List<String> trends;
  final List<String> problems;
  final List<String> recommendations;
  final List<DashboardInsightAlert> alerts;
  final DateTime? createdAt;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      explainability.isEmpty &&
      insights.isEmpty &&
      trends.isEmpty &&
      problems.isEmpty &&
      recommendations.isEmpty &&
      alerts.isEmpty;

  static List<String> _stringList(dynamic raw) {
    return (raw as List? ?? const [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  factory DashboardAiAnalysis.fromJson(Map<String, dynamic> json) {
    return DashboardAiAnalysis(
      id: '${json['id'] ?? ''}',
      analysisType:
          '${json['analysisType'] ?? json['analysis_type'] ?? 'dashboard'}',
      range: '${json['range'] ?? '7d'}',
      filterKey: '${json['filterKey'] ?? json['filter_key'] ?? 'default'}',
      filters: Map<String, dynamic>.from(json['filters'] as Map? ?? const {}),
      summary: '${json['summary'] ?? ''}'.trim(),
      explainability: _stringList(
        json['explainability'] ??
            json['explanation_points'] ??
            json['detected_factors'],
      ),
      insights: _stringList(json['insights']),
      trends: _stringList(json['trends']),
      problems: _stringList(json['problems']),
      recommendations: _stringList(json['recommendations']),
      alerts:
          (json['alerts'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (item) => DashboardInsightAlert.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((alert) => alert.message.isNotEmpty)
              .toList(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
    );
  }
}

typedef DashboardInsight = DashboardAiAnalysis;

class DashboardApi {
  DashboardApi._();
  static final DashboardApi instance = DashboardApi._();
  static const Duration _nlpRunTimeout = Duration(seconds: 45);
  static const Duration _nlpPollTimeout = Duration(minutes: 6);
  static const Duration _nlpPollInterval = Duration(seconds: 3);

  Future<DashboardSummary> loadSummary({
    DashboardFilters filters = const DashboardFilters(),
  }) async {
    final query = filters.toQuery();
    final path =
        Uri(
          path: '/api/manager/dashboard/summary',
          queryParameters: query.isEmpty ? null : query,
        ).toString();
    final decoded = await ApiClient.instance.getJson(path, useCache: false);
    return DashboardSummary.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<DashboardAiAnalysis?> loadLatestInsight({
    String range = '7d',
    DashboardFilters filters = const DashboardFilters(),
  }) async {
    final path =
        Uri(
          path: '/api/dashboard/insights',
          queryParameters: {
            'range': range,
            'orderSource': filters.orderSource,
            'businessSide': filters.businessSide,
            'cateringStyle': filters.cateringStyle,
          },
        ).toString();
    final decoded = await ApiClient.instance.getJson(path, useCache: false);
    final data = decoded['data'];
    if (data is! Map) return null;
    final insight = DashboardAiAnalysis.fromJson(
      Map<String, dynamic>.from(data),
    );
    return insight.isEmpty ? null : insight;
  }

  Future<DashboardAiAnalysis> analyzeDashboard({
    String range = '7d',
    String prompt = '',
    DashboardSummary? dashboardData,
    DashboardFilters filters = const DashboardFilters(),
    void Function(AiTaskState state)? onStateChanged,
  }) async {
    final trimmedPrompt = prompt.trim();
    onStateChanged?.call(AiTaskState.processing);
    final decoded = await ApiClient.instance.postJson(
      '/api/dashboard/analyze',
      body: {
        'range': range,
        ...filters.toAiJson(),
        'input': {
          'task_type': AiTaskTypes.dashboardAnalysis,
          'filters': filters.toAiJson(),
          'dashboard_data': {
            if (dashboardData != null) ...dashboardData.toJson(),
            'range': range,
          },
          if (trimmedPrompt.isNotEmpty) 'prompt': trimmedPrompt,
        },
      },
      timeout: _nlpPollTimeout,
    );
    final data = decoded['data'];
    if (data is! Map) {
      onStateChanged?.call(AiTaskState.failed);
      throw ApiError(message: 'Dashboard analysis returned no insight');
    }
    onStateChanged?.call(AiTaskState.completed);
    return DashboardAiAnalysis.fromJson(Map<String, dynamic>.from(data));
  }

  Future<DishTrendsResult> loadDishTrends({
    void Function(AiTaskState state)? onStateChanged,
  }) async {
    final result = await runNlpTask(
      AiTaskTypes.dishTrends,
      onStateChanged: onStateChanged,
    );
    return DishTrendsResult.fromJson(_extractNlpResult(result));
  }

  Future<AiHealthStatus> loadAiHealth({
    void Function(AiTaskState state)? onStateChanged,
  }) async {
    final result = await runNlpTask(
      AiTaskTypes.healthCheck,
      onStateChanged: onStateChanged,
    );
    return AiHealthStatus.fromJson(_extractNlpResult(result));
  }

  Future<Map<String, dynamic>> runNlpTask(
    String taskType, {
    Map<String, dynamic> input = const {},
    Duration timeout = _nlpPollTimeout,
    void Function(AiTaskState state)? onStateChanged,
  }) async {
    onStateChanged?.call(AiTaskState.processing);
    final decoded = await ApiClient.instance.postJson(
      '/api/runpod/nlp/run',
      body: {
        'input': {'task_type': taskType, ...input},
      },
      timeout: _nlpRunTimeout,
    );
    final status = _normalizeStatus(decoded['status']);
    if (_statusIsCompleted(status) || decoded['output'] != null) {
      onStateChanged?.call(AiTaskState.completed);
      return decoded;
    }
    if (_statusIsFailed(status)) {
      onStateChanged?.call(AiTaskState.failed);
      throw ApiError(message: _failureMessage(decoded));
    }
    final jobId = _extractJobId(decoded);
    if (jobId == null) {
      onStateChanged?.call(AiTaskState.completed);
      return decoded;
    }
    onStateChanged?.call(
      _statusIsQueued(status) ? AiTaskState.queued : AiTaskState.processing,
    );
    return pollJob(jobId, timeout: timeout, onStateChanged: onStateChanged);
  }

  Future<Map<String, dynamic>> pollJob(
    String jobId, {
    Duration timeout = _nlpPollTimeout,
    void Function(AiTaskState state)? onStateChanged,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_nlpPollInterval);
      final decoded = await ApiClient.instance.getJson(
        '/api/runpod/nlp/status/${Uri.encodeComponent(jobId)}',
        useCache: false,
      );
      final status = _normalizeStatus(decoded['status']);
      if (_statusIsCompleted(status)) {
        onStateChanged?.call(AiTaskState.completed);
        return decoded;
      }
      if (_statusIsFailed(status)) {
        onStateChanged?.call(AiTaskState.failed);
        throw ApiError(message: _failureMessage(decoded));
      }
      onStateChanged?.call(
        _statusIsQueued(status) && (status == 'IN_QUEUE' || status == 'QUEUED')
            ? AiTaskState.queued
            : AiTaskState.processing,
      );
    }
    onStateChanged?.call(AiTaskState.failed);
    throw ApiError(message: 'AI task timed out. Please try again.');
  }

  static String? _normalizeStatus(dynamic value) {
    if (value == null) return null;
    return '$value'.trim().toUpperCase();
  }

  static bool _statusIsCompleted(String? status) => status == 'COMPLETED';

  static bool _statusIsQueued(String? status) =>
      status == 'IN_QUEUE' ||
      status == 'QUEUED' ||
      status == 'IN_PROGRESS' ||
      status == 'RUNNING' ||
      status == 'PROCESSING' ||
      status == 'SUBMITTED';

  static bool _statusIsFailed(String? status) =>
      status == 'FAILED' || status == 'CANCELLED' || status == 'ERROR';

  static String? _extractJobId(Map<String, dynamic> data) {
    final direct = '${data['id'] ?? data['jobId'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;
    final job = data['job'];
    if (job is Map) {
      final nested = '${job['id'] ?? ''}'.trim();
      if (nested.isNotEmpty) return nested;
    }
    return null;
  }

  static String _failureMessage(Map<String, dynamic> data) {
    return '${data['error'] ?? data['message'] ?? 'AI task failed'}';
  }

  static Map<String, dynamic> _extractNlpResult(Map<String, dynamic> data) {
    Map<String, dynamic> map(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    final output = map(data['output']);
    final result = map(output['result']);
    if (result.isNotEmpty) return result;
    final analysis = map(output['analysis']);
    if (analysis.isNotEmpty) {
      return {...output, 'analysis': analysis};
    }
    if (output.isNotEmpty) return output;
    final dataMap = map(data['data']);
    if (dataMap.isNotEmpty) return dataMap;
    return data;
  }
}
