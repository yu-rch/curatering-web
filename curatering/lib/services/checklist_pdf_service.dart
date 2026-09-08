import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/event_order.dart';
import '../utils/pdf_print.dart';
import '../utils/print_tabular_report.dart';

bool checklistStatusIsCompleted(dynamic statusOrBool) {
  if (statusOrBool == true) return true;
  if (statusOrBool == false) return false;
  final status = '$statusOrBool'.trim().toLowerCase();
  if (status.isEmpty) return false;
  if (status.contains('not')) return false;
  return status == 'completed' ||
      status == 'done' ||
      status.contains('completed') ||
      status.contains('done');
}

String normalizeTaskStatusLabel(dynamic status) {
  return checklistStatusIsCompleted(status) ? 'completed' : 'not done';
}

String _pdfGeneratedStamp() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)} ${two(n.hour)}:${two(n.minute)}';
}

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
    return ChecklistPdfLine(
      item: '${row['item'] ?? row['title'] ?? ''}',
      description: '${row['description'] ?? ''}',
      quantity: () {
        final q = row['quantity'] ?? row['qty'] ?? 1;
        if (q is num) return q.toInt().clamp(1, 999999);
        return (int.tryParse('$q') ?? 1).clamp(1, 999999);
      }(),
      cost: double.tryParse('${row['cost'] ?? row['price'] ?? 0}') ?? 0,
      isCompleted: checklistStatusIsCompleted(row['status'] ?? row['isCompleted']),
    );
  }).toList();
  return buildChecklistPdfBytes(
    order: order,
    items: items,
    stageLabel: stageLabel,
  );
}

Future<void> previewChecklistPdf({
  required EventOrderDto order,
  required String stageLabel,
  required List<Map<String, dynamic>> checklistRows,
}) async {
  final items = checklistRows.map((row) {
    return ChecklistPdfLine(
      item: '${row['item'] ?? row['title'] ?? ''}',
      description: '${row['description'] ?? ''}',
      quantity: () {
        final q = row['quantity'] ?? row['qty'] ?? 1;
        if (q is num) return q.toInt().clamp(1, 999999);
        return (int.tryParse('$q') ?? 1).clamp(1, 999999);
      }(),
      cost: double.tryParse('${row['cost'] ?? row['price'] ?? 0}') ?? 0,
      isCompleted: checklistStatusIsCompleted(row['status'] ?? row['isCompleted']),
    );
  }).toList();

  final eventDate =
      order.scheduleSlots.isNotEmpty ? order.scheduleSlots.first.date : 'TBD';
  final rows = items.map((item) {
    final total = item.cost * item.quantity;
    return [
      item.item,
      item.description,
      '${item.quantity}',
      item.cost.toStringAsFixed(2),
      total.toStringAsFixed(2),
      item.isCompleted ? 'completed' : 'not done',
    ];
  }).toList();
  final grandTotal = items.fold<double>(
    0,
    (sum, item) => sum + (item.cost * item.quantity),
  );

  if (kIsWeb) {
    await printTabularReport(
      title: 'Event Checklist',
      filename: 'checklist.pdf',
      subtitle:
          "Macrina's Kitchen and Catering · Stage: $stageLabel · Generated ${_pdfGeneratedStamp()} · "
          'Event: ${order.eventTitle} · Customer: ${order.customerName} · Date: $eventDate · '
          'Txn: ${order.transactionNo} · Total: PHP ${grandTotal.toStringAsFixed(2)}',
      sections: [
        PrintableHtmlSection(
          title: 'Checklist items',
          headers: const [
            'Item',
            'Description',
            'Qty',
            'Unit (PHP)',
            'Total (PHP)',
            'Status',
          ],
          rows: rows,
        ),
      ],
    );
    return;
  }

  final bytes = await buildChecklistPdfBytes(
    order: order,
    items: items,
    stageLabel: stageLabel,
  );
  await printPdfBytes(bytes, name: 'checklist.pdf');
}

Future<Uint8List> buildTaskAssignmentPdf({
  required EventOrderDto order,
  required String stageLabel,
  required List<Map<String, dynamic>> taskRows,
}) async {
  final eventDate = order.scheduleSlots.isNotEmpty
      ? order.scheduleSlots.first.date
      : 'TBD';
  final generatedAt = _pdfGeneratedStamp();
  final headers = ['Employee', 'Task', 'Schedule', 'Budget', 'Status'];
  final rows = taskRows.map((row) {
    return [
      '${row['employee'] ?? row['assignee'] ?? row['assignedTo'] ?? row['assigned_to'] ?? ''}',
      '${row['tasks'] ?? row['task'] ?? row['title'] ?? row['item'] ?? ''}',
      '${row['schedule_of_tasks'] ?? row['notes'] ?? row['description'] ?? ''}',
      '${row['budget'] ?? ''}',
      normalizeTaskStatusLabel(row['status']),
    ];
  }).where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();

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
          pw.Text(
            'Generated: $generatedAt',
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
                    pw.Text(
                      'Transaction: ${order.transactionNo}',
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

Future<void> previewTaskAssignmentPdf({
  required EventOrderDto order,
  required String stageLabel,
  required List<Map<String, dynamic>> taskRows,
}) async {
  final eventDate =
      order.scheduleSlots.isNotEmpty ? order.scheduleSlots.first.date : 'TBD';
  final rows =
      taskRows
          .map((row) {
            return [
              '${row['employee'] ?? row['assignee'] ?? row['assignedTo'] ?? row['assigned_to'] ?? ''}',
              '${row['tasks'] ?? row['task'] ?? row['title'] ?? row['item'] ?? ''}',
              '${row['schedule_of_tasks'] ?? row['notes'] ?? row['description'] ?? ''}',
              '${row['budget'] ?? ''}',
              normalizeTaskStatusLabel(row['status']),
            ];
          })
          .where((row) => row.any((cell) => cell.trim().isNotEmpty))
          .toList();

  if (kIsWeb) {
    await printTabularReport(
      title: 'Task Assignment',
      filename: 'task-assignment.pdf',
      subtitle:
          "Macrina's Kitchen and Catering · Stage: $stageLabel · Generated ${_pdfGeneratedStamp()} · "
          'Event: ${order.eventTitle} · Customer: ${order.customerName} · Date: $eventDate · '
          'Txn: ${order.transactionNo}',
      sections: [
        PrintableHtmlSection(
          title: 'Assignments',
          headers: const ['Employee', 'Task', 'Schedule', 'Budget', 'Status'],
          rows: rows,
        ),
      ],
    );
    return;
  }

  final bytes = await buildTaskAssignmentPdf(
    order: order,
    stageLabel: stageLabel,
    taskRows: taskRows,
  );
  await printPdfBytes(bytes, name: 'task-assignment.pdf');
}

Future<Uint8List> buildChecklistPdfBytes({
  required EventOrderDto order,
  required List<ChecklistPdfLine> items,
  String stageLabel = '',
}) async {
  final eventDate = order.scheduleSlots.isNotEmpty
      ? order.scheduleSlots.first.date
      : 'TBD';
  final generatedAt = _pdfGeneratedStamp();

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
      item.isCompleted ? 'completed' : 'not done',
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
          pw.Text(
            'Generated: $generatedAt',
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
                    _pdfInfoRow('Event', order.eventTitle),
                    _pdfInfoRow('Customer', order.customerName),
                    _pdfInfoRow('Date', eventDate),
                    _pdfInfoRow('Transaction', order.transactionNo),
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
          if (rows.isEmpty)
            pw.Text(
              'No checklist items recorded.',
              style: const pw.TextStyle(fontSize: 11),
            )
          else
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
