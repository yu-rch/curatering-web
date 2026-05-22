import 'api_client.dart';

class ReportsSummaryData {
  const ReportsSummaryData({
    required this.period,
    required this.catering,
    required this.cateringEvents,
    required this.restaurant,
  });

  final Map<String, dynamic> period;
  final CateringReportSection catering;
  final CateringReportSection cateringEvents;
  final RestaurantReportSection restaurant;

  factory ReportsSummaryData.fromJson(Map<String, dynamic> json) {
    return ReportsSummaryData(
      period: Map<String, dynamic>.from(json['period'] as Map? ?? {}),
      catering: CateringReportSection.fromJson(
        Map<String, dynamic>.from(json['catering'] as Map? ?? {}),
      ),
      cateringEvents: CateringReportSection.fromJson(
        Map<String, dynamic>.from(
          (json['cateringEvents'] ?? json['catering_events']) as Map? ?? {},
        ),
      ),
      restaurant: RestaurantReportSection.fromJson(
        Map<String, dynamic>.from(json['restaurant'] as Map? ?? {}),
      ),
    );
  }
}

class CateringReportSection {
  const CateringReportSection({
    required this.orderCount,
    required this.totalSales,
    required this.averageGuestCount,
    required this.topDishes,
    required this.topEventTypes,
    required this.feedback,
  });

  final int orderCount;
  final double totalSales;
  final double averageGuestCount;
  final List<ReportRankItem> topDishes;
  final List<ReportRankItem> topEventTypes;
  final FeedbackReportMetrics feedback;

  factory CateringReportSection.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    List<ReportRankItem> list(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ReportRankItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return CateringReportSection(
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      totalSales: d(json['totalSales']),
      averageGuestCount: d(json['averageGuestCount']),
      topDishes: list(json['topDishes']),
      topEventTypes: list(json['topEventTypes']),
      feedback: FeedbackReportMetrics.fromJson(
        Map<String, dynamic>.from(json['feedback'] as Map? ?? {}),
      ),
    );
  }
}

class RestaurantReportSection {
  const RestaurantReportSection({
    required this.orderCount,
    required this.totalSales,
    required this.averageOrdersPerDay,
    required this.webPageViews,
    required this.mobilePageViews,
    required this.customerAccountsWeb,
    required this.customerAccountsMobile,
    required this.topDishes,
    required this.feedback,
  });

  final int orderCount;
  final double totalSales;
  final double averageOrdersPerDay;
  final int webPageViews;
  final int mobilePageViews;
  final int customerAccountsWeb;
  final int customerAccountsMobile;
  final List<ReportRankItem> topDishes;
  final FeedbackReportMetrics feedback;

  factory RestaurantReportSection.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    List<ReportRankItem> list(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ReportRankItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return RestaurantReportSection(
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      totalSales: d(json['totalSales']),
      averageOrdersPerDay: d(json['averageOrdersPerDay']),
      webPageViews: (json['webPageViews'] as num?)?.toInt() ?? 0,
      mobilePageViews: (json['mobilePageViews'] as num?)?.toInt() ?? 0,
      customerAccountsWeb: (json['customerAccountsWeb'] as num?)?.toInt() ?? 0,
      customerAccountsMobile:
          (json['customerAccountsMobile'] as num?)?.toInt() ?? 0,
      topDishes: list(json['topDishes']),
      feedback: FeedbackReportMetrics.fromJson(
        Map<String, dynamic>.from(json['feedback'] as Map? ?? {}),
      ),
    );
  }
}

class FeedbackReportMetrics {
  const FeedbackReportMetrics({
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

  factory FeedbackReportMetrics.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return FeedbackReportMetrics(
      count: i(json['count']),
      averageStars: d(json['averageStars']),
      positiveCount: i(json['positiveCount']),
      neutralCount: i(json['neutralCount']),
      negativeCount: i(json['negativeCount']),
      complaintCount: i(json['complaintCount']),
    );
  }
}

class ReportRankItem {
  const ReportRankItem({required this.name, required this.count});
  final String name;
  final int count;

  factory ReportRankItem.fromJson(Map<String, dynamic> json) {
    return ReportRankItem(
      name: (json['name'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportsApi {
  ReportsApi._();
  static final ReportsApi instance = ReportsApi._();

  Future<ReportsSummaryData> loadSummary({
    required int year,
    int? month,
    bool annual = false,
  }) async {
    final qp = <String, String>{
      'year': '$year',
      if (annual) 'annual': '1' else if (month != null) 'month': '$month',
    };
    final decoded = await ApiClient.instance.getJson(
      '/api/manager/reports/summary',
      queryParameters: qp,
      useCache: false,
    );
    return ReportsSummaryData.fromJson(Map<String, dynamic>.from(decoded));
  }
}
