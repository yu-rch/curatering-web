import 'api_client.dart';

class DashboardFilters {
  const DashboardFilters({
    this.start,
    this.end,
    this.orderSource = 'ALL',
    this.orderStatus = 'ALL',
  });

  final DateTime? start;
  final DateTime? end;
  final String orderSource;
  final String orderStatus;

  Map<String, String> toQuery() {
    final query = <String, String>{};
    if (start != null) query['start'] = _date(start!);
    if (end != null) query['end'] = _date(end!);
    if (orderSource != 'ALL') query['orderSource'] = orderSource;
    if (orderStatus != 'ALL') query['orderStatus'] = orderStatus;
    return query;
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

  factory FeedbackDashboardMetrics.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
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

class DashboardApi {
  DashboardApi._();
  static final DashboardApi instance = DashboardApi._();

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
}
