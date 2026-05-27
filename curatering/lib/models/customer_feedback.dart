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
    required this.sentiment,
    required this.keyTopics,
    required this.complaints,
    required this.praises,
    required this.insights,
    required this.source,
    required this.feedbackCount,
    required this.averageStars,
  });

  final String summary;
  final String interpretation;
  final List<String> recommendations;
  final String sentiment;
  final List<String> keyTopics;
  final List<String> complaints;
  final List<String> praises;
  final List<String> insights;
  final String source;
  final int feedbackCount;
  final double? averageStars;

  factory CustomerFeedbackAnalysis.fromJson(Map<String, dynamic> json) {
    List<String> stringList(dynamic raw) {
      String text(dynamic value) {
        if (value == null) return '';
        if (value is String || value is num || value is bool) {
          return '$value'.trim();
        }
        if (value is Map) {
          for (final key in const [
            'message',
            'summary',
            'title',
            'insight',
            'recommendation',
            'complaint',
            'praise',
            'topic',
            'description',
          ]) {
            final candidate = text(value[key]);
            if (candidate.isNotEmpty) return candidate;
          }
          return value.entries
              .map((entry) => '${entry.key}: ${text(entry.value)}'.trim())
              .where((item) => item.isNotEmpty && !item.endsWith(':'))
              .join(', ');
        }
        return '$value'.trim();
      }

      if (raw is List) {
        return raw.map(text).where((item) => item.isNotEmpty).toList();
      }
      if (raw is Map) {
        return raw.values.map(text).where((item) => item.isNotEmpty).toList();
      }
      final value = text(raw);
      return value.isEmpty ? const [] : [value];
    }

    return CustomerFeedbackAnalysis(
      summary: (json['summary'] ?? '').toString(),
      interpretation: (json['interpretation'] ?? '').toString(),
      recommendations: stringList(json['recommendations']),
      sentiment: (json['sentiment'] ?? '').toString(),
      keyTopics: stringList(json['keyTopics'] ?? json['key_topics']),
      complaints: stringList(json['complaints']),
      praises: stringList(json['praises']),
      insights: stringList(json['insights']),
      source: (json['source'] ?? 'heuristic').toString(),
      feedbackCount: (json['feedbackCount'] as num?)?.toInt() ?? 0,
      averageStars: (json['averageStars'] as num?)?.toDouble(),
    );
  }
}
