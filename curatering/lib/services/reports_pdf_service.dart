import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/event_order.dart';
import '../utils/order_calculations.dart';

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
    return dishCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  String get mostFrequentEventType {
    if (eventTypeCounts.isEmpty) return 'N/A';
    return eventTypeCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  List<MapEntry<String, int>> get topDishes {
    final list = dishCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
      final name = item.dishName.trim().isEmpty ? 'Unknown dish' : item.dishName;
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

String _orderDateLabel(EventOrderDto order) {
  if (order.scheduleSlots.isEmpty) return '—';
  final d = DateTime.tryParse(order.scheduleSlots.first.date);
  if (d == null) return order.scheduleSlots.first.date;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<Uint8List> buildMonthlyReportPdf(MonthlyReportSnapshot snapshot) async {
  final doc = pw.Document(
    title: 'Curatering Report — ${_monthLabel(snapshot.month)}',
    author: 'Curatering',
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
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: subStyle,
        ),
      ),
      build: (context) {
        final blocks = <pw.Widget>[
          pw.Text('Curatering', style: headerStyle),
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
          summaryRow(
            'Completed orders',
            '${snapshot.orders.length}',
          ),
          summaryRow('Total sales', formatPesos(snapshot.totalSales)),
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
          blocks.add(pw.Text('No dish data for this period.', style: cellStyle));
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

        blocks.addAll([
          pw.SizedBox(height: 20),
          pw.Text(
            'Completed orders',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
        ]);

        if (snapshot.orders.isEmpty) {
          blocks.add(
            pw.Text('No completed orders in this month.', style: cellStyle),
          );
        } else {
          blocks.add(
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    for (final h in [
                      'Date',
                      'Customer',
                      'Event',
                      'Guests',
                      'Sales',
                    ])
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: headerCellStyle),
                      ),
                  ],
                ),
                for (final o in snapshot.orders)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_orderDateLabel(o), style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(o.customerName, style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          o.eventTitle.isEmpty ? o.eventType : o.eventTitle,
                          style: cellStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${o.guestCount}', style: cellStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          formatPesos(orderRevenue(o)),
                          style: cellStyle,
                        ),
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
  await Printing.layoutPdf(
    onLayout: (_) => buildMonthlyReportPdf(snapshot),
    name: _reportFilename(snapshot.month),
  );
}

/// Download / share PDF (browser download on Flutter web).
Future<void> downloadMonthlyReportPdf(MonthlyReportSnapshot snapshot) async {
  final bytes = await buildMonthlyReportPdf(snapshot);
  await Printing.sharePdf(
    bytes: bytes,
    filename: _reportFilename(snapshot.month),
  );
}

String _reportFilename(DateTime month) {
  return 'curatering-report-${month.year}-${month.month.toString().padLeft(2, '0')}.pdf';
}
