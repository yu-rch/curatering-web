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

class OrderSummaryPdfData {
  const OrderSummaryPdfData({
    required this.title,
    required this.transactionNo,
    required this.processedAt,
    required this.eventTitle,
    required this.eventWhen,
    required this.customerName,
    required this.contactPerson,
    required this.contactNumber,
    required this.emailAddress,
    required this.cateringType,
    required this.eventType,
    required this.address,
    required this.serviceIncluded,
    required this.formalityLevel,
    required this.menuLines,
    required this.guestCount,
    required this.paxRate,
    required this.baseFoodCost,
    required this.paxBuffer,
    required this.themeCost,
    required this.additionalCostsSummary,
    required this.additionalCostTotal,
    required this.laborCost,
    required this.travelCost,
    required this.total,
    required this.amountDue,
    required this.note,
    this.isDownPayment = true,
  });

  final String title;
  final String transactionNo;
  final DateTime processedAt;
  final String eventTitle;
  final String eventWhen;
  final String customerName;
  final String contactPerson;
  final String contactNumber;
  final String emailAddress;
  final String cateringType;
  final String eventType;
  final String address;
  final String serviceIncluded;
  final String formalityLevel;
  final List<String> menuLines;
  final int guestCount;
  final double paxRate;
  final double baseFoodCost;
  final int paxBuffer;
  final double themeCost;
  final String additionalCostsSummary;
  final double additionalCostTotal;
  final double laborCost;
  final double travelCost;
  final double total;
  final double amountDue;
  final String note;
  final bool isDownPayment;
}

OrderSummaryPdfData buildOrderSummaryPdfData({
  required EventOrderDto order,
  required bool isDownPayment,
  double? amountDue,
  String? note,
}) {
  final slots = order.scheduleSlots;
  var eventWhen = '—';
  if (slots.isNotEmpty) {
    final s = slots.first;
    final parts = <String>[
      if (s.date.trim().isNotEmpty) s.date.trim(),
      if (s.startTime.trim().isNotEmpty) s.startTime.trim(),
    ];
    if (parts.isNotEmpty) eventWhen = parts.join(' ');
  }

  final menuLines =
      order.menu
          .map((m) => m.dishName.trim())
          .where((n) => n.isNotEmpty)
          .toList();

  final guestCount = order.guestCount;
  const paxRate = 0.0;
  final baseFoodCost =
      order.totalCost > 0 ? order.totalCost : computeOrderTotalCost(order);
  final labor = order.themeDesign.laborCost ?? 0;
  final travel = order.themeDesign.travelCost ?? 0;
  final themeCost = 0.0;
  final total = baseFoodCost + labor + travel + themeCost;
  final due = amountDue ?? (isDownPayment ? total / 2 : total);

  return OrderSummaryPdfData(
    title:
        isDownPayment
            ? 'Order Summary before Down Payment'
            : 'Order Summary | Additional Costs',
    transactionNo: order.cateringId.isNotEmpty ? order.cateringId : order.id,
    processedAt: DateTime.now(),
    eventTitle: order.eventTitle.trim().isNotEmpty
        ? order.eventTitle.trim()
        : order.customerName,
    eventWhen: eventWhen,
    customerName: order.customerName,
    contactPerson: order.contactPerson,
    contactNumber: order.contactNumber,
    emailAddress: order.emailAddress,
    cateringType: order.orderType,
    eventType: order.eventType,
    address: order.address,
    serviceIncluded: 'With service',
    formalityLevel:
        order.formalityLevel.trim().isEmpty ? '—' : order.formalityLevel,
    menuLines: menuLines,
    guestCount: guestCount,
    paxRate: paxRate,
    baseFoodCost: baseFoodCost,
    paxBuffer: 0,
    themeCost: themeCost,
    additionalCostsSummary: '',
    additionalCostTotal: 0,
    laborCost: labor,
    travelCost: travel,
    total: total,
    amountDue: due,
    note: note ?? '',
    isDownPayment: isDownPayment,
  );
}

Future<Uint8List> buildOrderSummaryPdfBytes(OrderSummaryPdfData d) async {
  final df = DateFormat('MMM d, yyyy h:mm a');
  pw.Widget row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) {
        if (d.isDownPayment) {
          return [
            pw.Text(
              d.title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              "Macrina's Kitchen and Catering",
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            row('Transaction No.', d.transactionNo),
            row('Date/Time processed', df.format(d.processedAt)),
            row('Event', d.eventTitle),
            row('Date/Time of Event', d.eventWhen),
            row('Customer', d.customerName),
            row('Contact person', d.contactPerson),
            row('Contact number', d.contactNumber),
            row('Email address', d.emailAddress),
            row('Catering type', d.cateringType),
            row('Event type', d.eventType),
            row('Address of event', d.address),
            row('Service', d.serviceIncluded),
            row('Formality level', d.formalityLevel),
            row(
              'Menu dishes',
              d.menuLines.isEmpty ? '—' : d.menuLines.join(', '),
            ),
            if (d.guestCount > 0 && d.paxRate > 0)
              row(
                'No. of PAX and cost',
                '${d.guestCount} x PHP ${d.paxRate.toStringAsFixed(0)} | PHP ${d.baseFoodCost.toStringAsFixed(2)}',
              )
            else if (d.guestCount > 0)
              row('No. of guests', '${d.guestCount}'),
            row('Labor cost', 'PHP ${d.laborCost.toStringAsFixed(2)}'),
            row('Travel cost', 'PHP ${d.travelCost.toStringAsFixed(2)}'),
            row('Total invoice', 'PHP ${d.total.toStringAsFixed(2)}'),
            row('Down payment due (50%)', 'PHP ${d.amountDue.toStringAsFixed(2)}'),
            if (d.note.trim().isNotEmpty) row('Note', d.note),
          ];
        }
        return [
          pw.Text(
            d.title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            "Macrina's Kitchen and Catering",
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Event information',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          row('Transaction No.', d.transactionNo),
          row('Event', d.eventTitle),
          row('Customer', d.customerName),
          row('Contact person', d.contactPerson),
          row('Contact number', d.contactNumber),
          row('Email address', d.emailAddress),
          row('Address', d.address),
          if (d.additionalCostTotal > 0.01) ...[
            row('Additional costs', d.additionalCostsSummary),
            row(
              'Additional costs (total)',
              'PHP ${d.additionalCostTotal.toStringAsFixed(2)}',
            ),
          ],
          row('Amount due', 'PHP ${d.amountDue.toStringAsFixed(2)}'),
        ];
      },
    ),
  );
  return doc.save();
}

Future<Uint8List> buildManagerOrderSummaryPdf({
  required EventOrderDto order,
  required OrderSummaryPdfVariant variant,
  List<Map<String, dynamic>> additionalCostGroups = const [],
}) async {
  final isDownPayment = variant == OrderSummaryPdfVariant.beforeDownPayment;

  var additionalTotal = 0.0;
  final summaryParts = <String>[];
  for (final group in additionalCostGroups) {
    final items = group['items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final label = '${item['label'] ?? item['name'] ?? 'Item'}'.trim();
        final amount =
            double.tryParse('${item['amount'] ?? item['cost'] ?? 0}') ?? 0;
        additionalTotal += amount;
        if (label.isNotEmpty) {
          summaryParts.add('$label (${amount.toStringAsFixed(2)})');
        }
      }
    } else if (group['total'] is num) {
      additionalTotal += (group['total'] as num).toDouble();
    }
  }

  final base = buildOrderSummaryPdfData(
    order: order,
    isDownPayment: isDownPayment,
  );

  final title = switch (variant) {
    OrderSummaryPdfVariant.beforeDownPayment =>
      'Order Summary before Down Payment',
    OrderSummaryPdfVariant.afterDownPayment =>
      'Order Summary after Down Payment',
    OrderSummaryPdfVariant.additionalCosts =>
      'Order Summary | Additional Costs',
    OrderSummaryPdfVariant.fullyPaid => 'Order Summary Fully Paid',
  };

  final total = switch (variant) {
    OrderSummaryPdfVariant.additionalCosts ||
    OrderSummaryPdfVariant.fullyPaid =>
      base.total + additionalTotal,
    _ => base.total,
  };

  final amountDue = switch (variant) {
    OrderSummaryPdfVariant.beforeDownPayment => total / 2,
    OrderSummaryPdfVariant.afterDownPayment => total / 2,
    OrderSummaryPdfVariant.additionalCosts => additionalTotal,
    OrderSummaryPdfVariant.fullyPaid => 0.0,
  };

  final data = OrderSummaryPdfData(
    title: title,
    transactionNo: order.transactionNo.isNotEmpty
        ? order.transactionNo
        : base.transactionNo,
    processedAt: base.processedAt,
    eventTitle: base.eventTitle,
    eventWhen: base.eventWhen,
    customerName: base.customerName,
    contactPerson: base.contactPerson,
    contactNumber: base.contactNumber,
    emailAddress: base.emailAddress,
    cateringType: base.cateringType,
    eventType: base.eventType,
    address: base.address,
    serviceIncluded: base.serviceIncluded,
    formalityLevel: base.formalityLevel,
    menuLines: base.menuLines,
    guestCount: base.guestCount,
    paxRate: base.paxRate,
    baseFoodCost: base.baseFoodCost,
    paxBuffer: base.paxBuffer,
    themeCost: base.themeCost,
    additionalCostsSummary: summaryParts.join(', '),
    additionalCostTotal: additionalTotal,
    laborCost: base.laborCost,
    travelCost: base.travelCost,
    total: total,
    amountDue: amountDue,
    note: base.note,
    isDownPayment: isDownPayment,
  );

  return buildOrderSummaryPdfBytes(data);
}
