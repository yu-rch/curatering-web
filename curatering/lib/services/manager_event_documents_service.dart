import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/event_order.dart';
import '../utils/order_calculations.dart';

enum OrderSummaryPdfVariant {
  beforeDownPayment,
  afterDownPayment,
  additionalCosts,
  fullyPaid,
}

Future<Uint8List> buildManagerOrderSummaryPdf({
  required EventOrderDto order,
  required OrderSummaryPdfVariant variant,
  List<Map<String, dynamic>> additionalCostGroups = const [],
}) async {
  final df = DateFormat('yyyy-MM-dd HH:mm');
  final processedAt = order.updatedAt ?? DateTime.now();

  pw.TableRow labelRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          color: PdfColors.grey300,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(value.isEmpty ? '—' : value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  String titleForVariant() {
    switch (variant) {
      case OrderSummaryPdfVariant.beforeDownPayment:
        return 'Order Summary before Down Payment';
      case OrderSummaryPdfVariant.afterDownPayment:
        return 'Order Summary after Down Payment';
      case OrderSummaryPdfVariant.additionalCosts:
        return 'Order Summary | Additional Costs';
      case OrderSummaryPdfVariant.fullyPaid:
        return 'Order Summary Fully Paid';
    }
  }

  final slots = order.scheduleSlots;
  var eventWhen = '—';
  if (slots.isNotEmpty) {
    final s = slots.first;
    eventWhen = '${s.date} ${s.startTime}'.trim();
    if (s.endTime.trim().isNotEmpty) eventWhen += ' to ${s.endTime}';
  }

  final menuLines =
      order.menu.map((m) => m.dishName.trim()).where((n) => n.isNotEmpty).toList();
  final total = order.totalCost > 0 ? order.totalCost : computeOrderTotalCost(order);
  final labor = order.themeDesign.laborCost ?? 0;
  final travel = order.themeDesign.travelCost ?? 0;
  final downDue = total * 0.5;
  final downPaid = order.downPaymentAmount > 0 ? order.downPaymentAmount : downDue;
  final balanceDue = (total - downPaid).clamp(0.0, double.infinity);
  final balancePaid = order.fullPaymentAmount > 0 ? order.fullPaymentAmount : balanceDue;
  final tx = order.cateringId.isNotEmpty ? order.cateringId : order.id;
  final cateringType =
      order.orderType.contains('event') ? 'Catering with Event Styling' : 'Catering';

  final doc = pw.Document();
  if (variant == OrderSummaryPdfVariant.additionalCosts) {
    final rows = <pw.TableRow>[
      labelRow('Transaction No.', tx),
      labelRow('Event', order.eventTitle.isEmpty ? order.customerName : order.eventTitle),
      labelRow('Customer', order.customerName),
      labelRow('Address', order.address),
    ];
    for (final group in additionalCostGroups) {
      final items = group['items'];
      final labels = <String>[];
      if (items is List) {
        for (final it in items) {
          if (it is Map) {
            final l = '${it['label'] ?? ''}'.trim();
            if (l.isNotEmpty) labels.add(l);
          }
        }
      }
      final stage = '${group['stage'] ?? 'Additional costs'}';
      final groupTotal = group['total'];
      rows.add(labelRow('Additional costs ($stage)', labels.join(' · ')));
      rows.add(labelRow(
        'Additional costs (total)',
        'PHP ${(groupTotal is num ? groupTotal.toDouble() : double.tryParse('$groupTotal') ?? 0).toStringAsFixed(2)}',
      ));
    }
    rows.add(labelRow('Total Cost', 'PHP ${total.toStringAsFixed(2)}'));
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(titleForVariant(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text("Macrina's Kitchen and Catering", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5), children: rows),
        ],
      ),
    );
    return doc.save();
  }

  final tail = <pw.TableRow>[];
  switch (variant) {
    case OrderSummaryPdfVariant.beforeDownPayment:
      tail.addAll([
        labelRow('Estimated Cost', 'PHP ${total.toStringAsFixed(2)}'),
        labelRow('Down payment due (50%)', 'PHP ${downDue.toStringAsFixed(2)}'),
      ]);
      break;
    case OrderSummaryPdfVariant.afterDownPayment:
      tail.addAll([
        labelRow('Total Cost', 'PHP ${total.toStringAsFixed(2)}'),
        labelRow('Down payment paid', 'PHP ${downPaid.toStringAsFixed(2)}'),
        labelRow('Balance amount due', 'PHP ${balanceDue.toStringAsFixed(2)}'),
      ]);
      break;
    case OrderSummaryPdfVariant.fullyPaid:
      tail.addAll([
        labelRow('Total Cost', 'PHP ${total.toStringAsFixed(2)}'),
        labelRow('Down payment paid', 'PHP ${downPaid.toStringAsFixed(2)}'),
        labelRow('Balance amount paid', 'PHP ${balancePaid.toStringAsFixed(2)}'),
      ]);
      break;
    case OrderSummaryPdfVariant.additionalCosts:
      break;
  }

  final bodyRows = <pw.TableRow>[
    labelRow('Transaction No.', tx),
    labelRow('Date/Time processed', df.format(processedAt)),
    labelRow('Event', order.eventTitle.isEmpty ? order.customerName : order.eventTitle),
    labelRow('Date/Time of Event', eventWhen),
    labelRow('Customer', order.customerName),
    labelRow('Contact person', order.contactPerson),
    labelRow('Contact number', order.contactNumber),
    labelRow('Email address', order.emailAddress),
    labelRow('Catering type', cateringType),
    labelRow('Address of event', order.address),
    labelRow('Menu dishes', menuLines.isEmpty ? '—' : menuLines.join(', ')),
    if (order.guestCount > 0)
      labelRow(
        'No. of PAX and cost',
        '${order.guestCount} x PHP 500 | PHP ${(order.guestCount * 500).toStringAsFixed(2)}',
      ),
    labelRow('Labor cost', 'PHP ${labor.toStringAsFixed(2)}'),
    labelRow('Travel cost', 'PHP ${travel.toStringAsFixed(2)}'),
    ...tail,
  ];

  doc.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text(titleForVariant(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text("Macrina's Kitchen and Catering", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5), children: bodyRows),
        if (variant == OrderSummaryPdfVariant.fullyPaid) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'PAID',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green,
            ),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> buildChecklistPdf({
  required EventOrderDto order,
  required String stageLabel,
  required List<Map<String, dynamic>> checklistRows,
}) async {
  final doc = pw.Document();
  final generatedAt = DateTime.now().toLocal().toString();
  final slots = order.scheduleSlots;
  var eventWhen = '—';
  if (slots.isNotEmpty) {
    final s = slots.first;
    eventWhen = '${s.date} ${s.startTime}'.trim();
  }
  final rows = checklistRows.map((cr) {
    return [
      '${cr['item'] ?? cr['title'] ?? ''}',
      '${cr['description'] ?? ''}',
      '${cr['quantity'] ?? ''}',
      '${cr['cost'] ?? cr['price'] ?? ''}',
      '${cr['status'] ?? (cr['isCompleted'] == true ? 'done' : 'not done')}',
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text('Checklist', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('Event: ${order.eventTitle.isEmpty ? order.customerName : order.eventTitle}'),
        pw.Text('Customer: ${order.customerName}'),
        pw.Text('Transaction: ${order.cateringId.isEmpty ? order.id : order.cateringId}'),
        pw.Text('Date / time of event: $eventWhen'),
        pw.Text('Stage: $stageLabel'),
        pw.Text('Generated: $generatedAt'),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Description', 'Quantity', 'Cost', 'Status'],
          data: rows.isEmpty ? const [['', 'No checklist items.', '', '', '']] : rows,
        ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> buildTaskAssignmentPdf({
  required EventOrderDto order,
  required String stageLabel,
  required List<Map<String, dynamic>> taskRows,
}) async {
  final doc = pw.Document();
  final generatedAt = DateTime.now().toLocal().toString();
  final rows = taskRows
      .map(
        (r) => [
          '${r['employee'] ?? ''}',
          '${r['tasks'] ?? r['task'] ?? ''}',
          '${r['schedule_of_tasks'] ?? r['schedule'] ?? ''}',
          '${r['budget'] ?? ''}',
          '${r['status'] ?? 'not done'}',
        ],
      )
      .toList();

  doc.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text('Task Assignment', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('Event: ${order.eventTitle.isEmpty ? order.customerName : order.eventTitle}'),
        pw.Text('Customer: ${order.customerName}'),
        pw.Text('Stage: $stageLabel'),
        pw.Text('Generated: $generatedAt'),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: const ['Employee', 'Task', 'Schedule of Task', 'Budget', 'Status'],
          data: rows.isEmpty ? const [['', 'No task assignment rows.', '', '', '']] : rows,
        ),
      ],
    ),
  );
  return doc.save();
}
