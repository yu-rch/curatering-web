import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/event_order.dart';

class ChecklistPdfLine {
  const ChecklistPdfLine({
    required this.item,
    required this.description,
    required this.quantity,
    required this.cost,
    required this.isCompleted,
  });

  final String item;
  final String description;
  final int quantity;
  final double cost;
  final bool isCompleted;
}

Future<Uint8List> buildChecklistPdf({
  required EventOrderDto order,
  required String stageLabel,
  required List<Map<String, dynamic>> checklistRows,
}) async {
  final items = checklistRows.map((row) {
    final status = '${row['status'] ?? ''}'.toLowerCase();
    return ChecklistPdfLine(
      item: '${row['item'] ?? row['title'] ?? ''}',
      description: '${row['description'] ?? ''}',
      quantity: () {
        final q = row['quantity'] ?? row['qty'] ?? 1;
        if (q is num) return q.toInt().clamp(1, 999999);
        return (int.tryParse('$q') ?? 1).clamp(1, 999999);
      }(),
      cost: double.tryParse('${row['cost'] ?? row['price'] ?? 0}') ?? 0,
      isCompleted: status.contains('done') && !status.contains('not'),
    );
  }).toList();
  return buildChecklistPdfBytes(
    order: order,
    items: items,
    stageLabel: stageLabel,
  );
}

Future<Uint8List> buildTaskAssignmentPdf({
  required EventOrderDto order,
  required String stageLabel,
  required List<Map<String, dynamic>> taskRows,
}) async {
  final eventDate = order.scheduleSlots.isNotEmpty
      ? order.scheduleSlots.first.date
      : 'TBD';
  final headers = ['Task', 'Assignee', 'Notes', 'Status'];
  final rows = taskRows.map((row) {
    return [
      '${row['task'] ?? row['title'] ?? row['item'] ?? ''}',
      '${row['assignee'] ?? row['assignedTo'] ?? row['assigned_to'] ?? ''}',
      '${row['notes'] ?? row['description'] ?? ''}',
      '${row['status'] ?? 'pending'}',
    ];
  }).toList();

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return [
          pw.Text(
            'Task Assignment',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            "Macrina's Kitchen and Catering",
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Stage: $stageLabel',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Event: ${order.eventTitle.trim().isEmpty ? order.customerName : order.eventTitle}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Date: $eventDate',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Customer: ${order.customerName}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          if (rows.isEmpty)
            pw.Text(
              'No task assignments recorded.',
              style: const pw.TextStyle(fontSize: 11),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
        ];
      },
    ),
  );
  return doc.save();
}

Future<Uint8List> buildChecklistPdfBytes({
  required EventOrderDto order,
  required List<ChecklistPdfLine> items,
  String stageLabel = '',
}) async {
  final eventDate = order.scheduleSlots.isNotEmpty
      ? order.scheduleSlots.first.date
      : 'TBD';

  final headers = [
    'Item',
    'Description',
    'Qty',
    'Unit (PHP)',
    'Total (PHP)',
    'Status',
  ];

  final rows = items.map((item) {
    final total = item.cost * item.quantity;
    return [
      item.item,
      item.description,
      '${item.quantity}',
      item.cost.toStringAsFixed(2),
      total.toStringAsFixed(2),
      item.isCompleted ? 'Completed' : 'Pending',
    ];
  }).toList();

  final grandTotal = items.fold<double>(
    0,
    (sum, item) => sum + (item.cost * item.quantity),
  );

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return [
          pw.Text(
            'Event Checklist',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            "Macrina's Kitchen and Catering",
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (stageLabel.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Stage: ${stageLabel.trim()}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfInfoRow('Event', order.eventTitle),
                    _pdfInfoRow('Customer', order.customerName),
                    _pdfInfoRow('Date', eventDate),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfInfoRow('Contact', order.contactPerson),
                    _pdfInfoRow('Phone', order.contactNumber),
                    _pdfInfoRow('Guests', '${order.guestCount}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(2),
              2: pw.FixedColumnWidth(28),
              3: pw.FixedColumnWidth(52),
              4: pw.FixedColumnWidth(52),
              5: pw.FixedColumnWidth(58),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total cost: PHP ${grandTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ];
      },
    ),
  );

  return doc.save();
}

pw.Widget _pdfInfoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          ),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    ),
  );
}
