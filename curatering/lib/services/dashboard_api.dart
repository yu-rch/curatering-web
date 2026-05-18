import 'api_client.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.restaurant,
    required this.catering,
    required this.salesThisYear,
  });

  final RestaurantDashboardMetrics restaurant;
  final CateringDashboardMetrics catering;
  final SalesYearBreakdown salesThisYear;

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
  });

  final int pendingConfirmations;
  final int delivered;
  final int cancelled;
  final double salesToday;
  final double salesThisYear;

  factory RestaurantDashboardMetrics.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return RestaurantDashboardMetrics(
      pendingConfirmations: (json['pendingConfirmations'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      salesToday: d(json['salesToday']),
      salesThisYear: d(json['salesThisYear']),
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

  factory CateringDashboardMetrics.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return CateringDashboardMetrics(
      inquiriesThisMonth: (json['inquiriesThisMonth'] as num?)?.toInt() ?? 0,
      acceptedTransactions: (json['acceptedTransactions'] as num?)?.toInt() ?? 0,
      forDownPayment: (json['forDownPayment'] as num?)?.toInt() ?? 0,
      ongoing: (json['ongoing'] as num?)?.toInt() ?? 0,
      forFullPayment: (json['forFullPayment'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      salesToday: d(json['salesToday']),
      salesThisYear: d(json['salesThisYear']),
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
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return SalesYearBreakdown(
      restaurant: d(json['restaurant']),
      catering: d(json['catering']),
      all: d(json['all']),
    );
  }
}

class DashboardApi {
  DashboardApi._();
  static final DashboardApi instance = DashboardApi._();

  Future<DashboardSummary> loadSummary() async {
    final decoded = await ApiClient.instance.getJson(
      '/api/manager/dashboard/summary',
      useCache: false,
    );
    return DashboardSummary.fromJson(Map<String, dynamic>.from(decoded));
  }
}
