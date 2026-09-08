import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/event_order.dart';
import '../utils/order_calculations.dart';
import '../utils/pdf_print.dart';
import '../utils/print_tabular_report.dart';
import 'reports_api.dart';

/// Aggregated metrics for one calendar month.
class MonthlyReportSnapshot {
  final DateTime month;
  final List<EventOrderDto> orders;
  final double totalSales;
  final Map<String, int> dishCounts;
  final Map<String, int> eventTypeCounts;

  MonthlyReportSnapshot({
    required this.month,
    required this.orders,
    required this.totalSales,
    required this.dishCounts,
    required this.eventTypeCounts,
  });

  String get popularDish {
    if (dishCounts.isEmpty) return 'N/A';
    return dishCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String get mostFrequentEventType {
    if (eventTypeCounts.isEmpty) return 'N/A';
    return eventTypeCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  List<MapEntry<String, int>> get topDishes {
    final list =
        dishCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

double orderRevenue(EventOrderDto order) {
  if (order.totalCost > 0) return order.totalCost;
  return computeOrderTotalCost(order);
}

MonthlyReportSnapshot buildMonthlyReportSnapshot({
  required DateTime month,
  required List<EventOrderDto> orders,
}) {
  final dishCounts = <String, int>{};
  final eventTypeCounts = <String, int>{};
  var totalSales = 0.0;

  for (final o in orders) {
    totalSales += orderRevenue(o);
    final et = o.eventType.trim().isEmpty ? 'Unspecified' : o.eventType;
    eventTypeCounts[et] = (eventTypeCounts[et] ?? 0) + 1;
    for (final item in o.menu) {
      final name =
          item.dishName.trim().isEmpty ? 'Unknown dish' : item.dishName;
      dishCounts[name] = (dishCounts[name] ?? 0) + 1;
    }
  }

  return MonthlyReportSnapshot(
    month: month,
    orders: orders,
    totalSales: totalSales,
    dishCounts: dishCounts,
    eventTypeCounts: eventTypeCounts,
  );
}

String _monthLabel(DateTime month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

Future<Uint8List> buildMonthlyReportPdf(MonthlyReportSnapshot snapshot) async {
  final doc = pw.Document(
    title:
        "Macrina's Kitchen and Catering Report — ${_monthLabel(snapshot.month)}",
    author: "Macrina's Kitchen and Catering",
  );

  final generatedAt = DateTime.now();
  final headerStyle = pw.TextStyle(
    fontSize: 18,
    fontWeight: pw.FontWeight.bold,
  );
  final subStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey700);
  final cellStyle = const pw.TextStyle(fontSize: 9);
  final headerCellStyle = pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
  );

  pw.Widget summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 2, child: pw.Text(label, style: cellStyle)),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer:
          (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: subStyle,
            ),
          ),
      build: (context) {
        final blocks = <pw.Widget>[
          pw.Text("Macrina's Kitchen and Catering", style: headerStyle),
          pw.SizedBox(height: 4),
          pw.Text('Monthly Operations Report', style: subStyle),
          pw.SizedBox(height: 4),
          pw.Text('Period: ${_monthLabel(snapshot.month)}', style: subStyle),
          pw.Text(
            'Generated: ${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
            '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}',
            style: subStyle,
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          summaryRow('Completed orders', '${snapshot.orders.length}'),
          summaryRow('Total sales', formatPhp(snapshot.totalSales)),
          summaryRow('Most popular dish', snapshot.popularDish),
          summaryRow(
            'Most frequent event type',
            snapshot.mostFrequentEventType,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Top requested dishes',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
        ];

        if (snapshot.topDishes.isEmpty) {
          blocks.add(
            pw.Text('No dish data for this period.', style: cellStyle),
          );
        } else {
          blocks.add(
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Dish', style: headerCellStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Count', style: headerCellStyle),
                    ),
                  ],
                ),
                for (final e in snapshot.topDishes.take(15))
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(e.key, style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${e.value}', style: cellStyle),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }

        return blocks;
      },
    ),
  );

  return doc.save();
}

/// Opens print preview on web/desktop; triggers download where supported.
Future<void> previewMonthlyReportPdf(MonthlyReportSnapshot snapshot) async {
  if (kIsWeb) {
    await printTabularReport(
      title: "Macrina's Kitchen and Catering — ${_monthLabel(snapshot.month)}",
      filename: _reportFilename(snapshot.month),
      subtitle:
          'Monthly Operations Report · Period: ${_monthLabel(snapshot.month)} · Generated ${DateTime.now().toLocal()}',
      sections: [
        PrintableHtmlSection(
          title: 'Summary',
          headers: const ['Metric', 'Value'],
          rows: [
            ['Completed orders', '${snapshot.orders.length}'],
            ['Total sales', formatPhp(snapshot.totalSales)],
            ['Most popular dish', snapshot.popularDish],
            ['Most frequent event type', snapshot.mostFrequentEventType],
          ],
        ),
        PrintableHtmlSection(
          title: 'Top requested dishes',
          headers: const ['Dish', 'Count'],
          rows: [
            for (final e in snapshot.topDishes.take(15)) [e.key, '${e.value}'],
          ],
        ),
      ],
    );
    return;
  }
  final bytes = await buildMonthlyReportPdf(snapshot);
  await printPdfBytes(bytes, name: _reportFilename(snapshot.month));
}

/// Download / share PDF (browser download on Flutter web).
Future<void> downloadMonthlyReportPdf(MonthlyReportSnapshot snapshot) async {
  await previewMonthlyReportPdf(snapshot);
}

String _reportFilename(DateTime month) {
  return 'macrinas-report-${month.year}-${month.month.toString().padLeft(2, '0')}.pdf';
}

String _periodLabel({required bool annual, required int year, int? month}) {
  if (annual) return 'Year $year';
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[(month ?? 1) - 1]} $year';
}

Future<Uint8List> buildOperationsReportPdf({
  required ReportsSummaryData data,
  required String scope,
  required bool annual,
  required int year,
  int? month,
}) async {
  final doc = pw.Document(
    title: "Macrina's Kitchen and Catering Report",
    author: "Macrina's Kitchen and Catering",
  );
  final generatedAt = DateTime.now();
  final headerStyle = pw.TextStyle(
    fontSize: 16,
    fontWeight: pw.FontWeight.bold,
  );
  final subStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey700);
  final cellStyle = const pw.TextStyle(fontSize: 9);
  final headerCellStyle = pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
  );

  pw.Widget summaryTable(String title, List<List<String>> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Metric', style: headerCellStyle),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Value', style: headerCellStyle),
                ),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[0], style: cellStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[1], style: cellStyle),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget chartBars(String title, List<ReportRankItem> items) {
    final top = items.take(8).toList();
    final max = top.fold<int>(1, (m, e) => e.count > m ? e.count : m);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (top.isEmpty)
          pw.Text('No chart data.', style: cellStyle)
        else
          for (final e in top)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 120,
                    child: pw.Text(e.name, style: cellStyle),
                  ),
                  pw.SizedBox(
                    width: 180,
                    child: pw.Container(
                      height: 10,
                      color: PdfColors.grey200,
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Container(
                          width: 180 * e.count / max,
                          height: 10,
                          color: PdfColors.blue600,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text('${e.count}', style: cellStyle),
                ],
              ),
            ),
      ],
    );
  }

  pw.Widget rankTable(String title, List<ReportRankItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (items.isEmpty)
          pw.Text('No data.', style: cellStyle)
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Name', style: headerCellStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Count', style: headerCellStyle),
                  ),
                ],
              ),
              for (final e in items.take(15))
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(e.name, style: cellStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${e.count}', style: cellStyle),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  final blocks = <pw.Widget>[
    pw.Text("Macrina's Kitchen and Catering", style: headerStyle),
    pw.SizedBox(height: 4),
    pw.Text('Operations Report', style: subStyle),
    pw.Text(
      'Period: ${_periodLabel(annual: annual, year: year, month: month)}',
      style: subStyle,
    ),
    pw.Text(
      'As of ${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} ${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}',
      style: subStyle,
    ),
    pw.SizedBox(height: 16),
  ];

  if (scope == 'combined' || scope == 'catering') {
    blocks.add(pw.Text('Catering — Summary', style: headerStyle));
    blocks.add(
      summaryTable('Catering Summary Table', [
        ['Completed orders', '${data.catering.orderCount}'],
        ['Total sales', formatPhp(data.catering.totalSales)],
        [
          'Average guest count',
          data.catering.averageGuestCount.toStringAsFixed(1),
        ],
        [
          'Catering feedback complaints',
          '${data.catering.feedback.complaintCount}',
        ],
        ['Orders with complaints', '${data.catering.feedback.count}'],
      ]),
    );
    blocks.add(
      chartBars('Top Requested Dishes Chart', data.catering.topDishes),
    );
    blocks.add(rankTable('Top requested dishes', data.catering.topDishes));
  }

  if (scope == 'combined' || scope == 'catering+events') {
    blocks.add(pw.SizedBox(height: 8));
    blocks.add(pw.Text('Catering + Events — Summary', style: headerStyle));
    blocks.add(
      summaryTable('Catering + Events Summary Table', [
        ['Completed orders', '${data.cateringEvents.orderCount}'],
        ['Total sales', formatPhp(data.cateringEvents.totalSales)],
        [
          'Average guest count',
          data.cateringEvents.averageGuestCount.toStringAsFixed(1),
        ],
        [
          'Feedback complaints',
          '${data.cateringEvents.feedback.complaintCount}',
        ],
        ['Events with complaints', '${data.cateringEvents.feedback.count}'],
      ]),
    );
    blocks.add(
      chartBars('Event Types Chart', data.cateringEvents.topEventTypes),
    );
    blocks.add(
      rankTable('Most frequent event type', data.cateringEvents.topEventTypes),
    );
  }

  if (scope == 'combined' || scope == 'restaurant') {
    blocks.add(pw.SizedBox(height: 8));
    blocks.add(pw.Text('Restaurant — Summary', style: headerStyle));
    blocks.add(
      summaryTable('Restaurant Summary Table', [
        ['Orders', '${data.restaurant.orderCount}'],
        ['Total sales', formatPhp(data.restaurant.totalSales)],
        [
          'Average orders per day',
          data.restaurant.averageOrdersPerDay.toStringAsFixed(2),
        ],
        ['Web page views', '${data.restaurant.webPageViews}'],
        ['Mobile page views', '${data.restaurant.mobilePageViews}'],
        ['Customer accounts (web)', '${data.restaurant.customerAccountsWeb}'],
        [
          'Customer accounts (mobile)',
          '${data.restaurant.customerAccountsMobile}',
        ],
        ['Feedback submissions', '${data.restaurant.feedback.count}'],
        [
          'Average feedback rating',
          '${data.restaurant.feedback.averageStars.toStringAsFixed(1)} / 5',
        ],
        [
          'Positive / Neutral / Negative',
          '${data.restaurant.feedback.positiveCount} / ${data.restaurant.feedback.neutralCount} / ${data.restaurant.feedback.negativeCount}',
        ],
      ]),
    );
    blocks.add(
      chartBars('Most Ordered Dishes Chart', data.restaurant.topDishes),
    );
    blocks.add(rankTable('Most ordered dishes', data.restaurant.topDishes));
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer:
          (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: subStyle,
            ),
          ),
      build: (_) => blocks,
    ),
  );

  return doc.save();
}

Future<void> previewOperationsReportPdf({
  required ReportsSummaryData data,
  required String scope,
  required bool annual,
  required int year,
  int? month,
}) async {
  final name =
      annual
          ? 'macrinas-report-$year.pdf'
          : 'macrinas-report-$year-${(month ?? 1).toString().padLeft(2, '0')}.pdf';
  if (kIsWeb) {
    final sections = <PrintableHtmlSection>[];
    if (scope == 'combined' || scope == 'catering') {
      sections.add(
        PrintableHtmlSection(
          title: 'Catering Summary',
          headers: const ['Metric', 'Value'],
          rows: [
            ['Completed orders', '${data.catering.orderCount}'],
            ['Total sales', formatPhp(data.catering.totalSales)],
            [
              'Average guest count',
              data.catering.averageGuestCount.toStringAsFixed(1),
            ],
            [
              'Catering feedback complaints',
              '${data.catering.feedback.complaintCount}',
            ],
            ['Orders with complaints', '${data.catering.feedback.count}'],
          ],
        ),
      );
      sections.add(
        PrintableHtmlSection(
          title: 'Top requested dishes',
          headers: const ['Name', 'Count'],
          rows: [
            for (final e in data.catering.topDishes.take(15))
              [e.name, '${e.count}'],
          ],
        ),
      );
    }
    if (scope == 'combined' || scope == 'catering+events') {
      sections.add(
        PrintableHtmlSection(
          title: 'Catering + Events Summary',
          headers: const ['Metric', 'Value'],
          rows: [
            ['Completed orders', '${data.cateringEvents.orderCount}'],
            ['Total sales', formatPhp(data.cateringEvents.totalSales)],
            [
              'Average guest count',
              data.cateringEvents.averageGuestCount.toStringAsFixed(1),
            ],
            [
              'Feedback complaints',
              '${data.cateringEvents.feedback.complaintCount}',
            ],
            ['Events with complaints', '${data.cateringEvents.feedback.count}'],
          ],
        ),
      );
      sections.add(
        PrintableHtmlSection(
          title: 'Most frequent event types',
          headers: const ['Name', 'Count'],
          rows: [
            for (final e in data.cateringEvents.topEventTypes.take(15))
              [e.name, '${e.count}'],
          ],
        ),
      );
    }
    if (scope == 'combined' || scope == 'restaurant') {
      sections.add(
        PrintableHtmlSection(
          title: 'Restaurant Summary',
          headers: const ['Metric', 'Value'],
          rows: [
            ['Orders', '${data.restaurant.orderCount}'],
            ['Total sales', formatPhp(data.restaurant.totalSales)],
            [
              'Average orders per day',
              data.restaurant.averageOrdersPerDay.toStringAsFixed(2),
            ],
            ['Web page views', '${data.restaurant.webPageViews}'],
            ['Mobile page views', '${data.restaurant.mobilePageViews}'],
            [
              'Customer accounts (web)',
              '${data.restaurant.customerAccountsWeb}',
            ],
            [
              'Customer accounts (mobile)',
              '${data.restaurant.customerAccountsMobile}',
            ],
            ['Feedback submissions', '${data.restaurant.feedback.count}'],
            [
              'Average feedback rating',
              '${data.restaurant.feedback.averageStars.toStringAsFixed(1)} / 5',
            ],
            [
              'Positive / Neutral / Negative',
              '${data.restaurant.feedback.positiveCount} / ${data.restaurant.feedback.neutralCount} / ${data.restaurant.feedback.negativeCount}',
            ],
          ],
        ),
      );
      sections.add(
        PrintableHtmlSection(
          title: 'Most ordered dishes',
          headers: const ['Name', 'Count'],
          rows: [
            for (final e in data.restaurant.topDishes.take(15))
              [e.name, '${e.count}'],
          ],
        ),
      );
    }
    await printTabularReport(
      title: "Macrina's Kitchen and Catering — Operations Report",
      filename: name,
      subtitle:
          'Period: ${_periodLabel(annual: annual, year: year, month: month)} · Generated ${DateTime.now().toLocal()}',
      sections: sections,
    );
    return;
  }

  final bytes = await buildOperationsReportPdf(
    data: data,
    scope: scope,
    annual: annual,
    year: year,
    month: month,
  );
  await printPdfBytes(bytes, name: name);
}

Future<void> downloadOperationsReportPdf({
  required ReportsSummaryData data,
  required String scope,
  required bool annual,
  required int year,
  int? month,
}) async {
  await previewOperationsReportPdf(
    data: data,
    scope: scope,
    annual: annual,
    year: year,
    month: month,
  );
}
