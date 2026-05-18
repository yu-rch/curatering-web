class CustomerFeedbackDto {
  const CustomerFeedbackDto({
    required this.id,
    required this.orderNo,
    required this.customerName,
    required this.customerEmail,
    required this.stars,
    required this.remarks,
    required this.submittedAt,
  });

  final String id;
  final String orderNo;
  final String customerName;
  final String customerEmail;
  final int stars;
  final String remarks;
  final DateTime? submittedAt;

  factory CustomerFeedbackDto.fromJson(Map<String, dynamic> json) {
    final submittedRaw = json['submittedAt'];
    return CustomerFeedbackDto(
      id: json['id'].toString(),
      orderNo: (json['orderNo'] ?? '').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      customerEmail: (json['customerEmail'] ?? '').toString(),
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      remarks: (json['remarks'] ?? '').toString(),
      submittedAt:
          submittedRaw == null
              ? null
              : DateTime.tryParse(submittedRaw.toString()),
    );
  }
}

class CustomerFeedbackAnalysis {
  const CustomerFeedbackAnalysis({
    required this.summary,
    required this.interpretation,
    required this.recommendations,
    required this.source,
    required this.feedbackCount,
    required this.averageStars,
  });

  final String summary;
  final String interpretation;
  final List<String> recommendations;
  final String source;
  final int feedbackCount;
  final double? averageStars;

  factory CustomerFeedbackAnalysis.fromJson(Map<String, dynamic> json) {
    final recRaw = json['recommendations'];
    return CustomerFeedbackAnalysis(
      summary: (json['summary'] ?? '').toString(),
      interpretation: (json['interpretation'] ?? '').toString(),
      recommendations:
          recRaw is List
              ? recRaw.map((e) => e.toString()).toList()
              : const [],
      source: (json['source'] ?? 'heuristic').toString(),
      feedbackCount: (json['feedbackCount'] as num?)?.toInt() ?? 0,
      averageStars: (json['averageStars'] as num?)?.toDouble(),
    );
  }
}
