import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_print.dart';
import 'printable_html_report.dart';
import 'web_html_print.dart';

export 'printable_html_report.dart' show PrintableHtmlSection, buildPrintableHtmlReport;

/// Shared Print PDF path used by Action Logs / tables / dashboards.
///
/// On web, opens a printable HTML preview (avoids `package:pdf` freezing the
/// UI). On native, builds a PDF and opens the system print dialog.
Future<void> printTabularReport({
  required String title,
  required List<PrintableHtmlSection> sections,
  String? subtitle,
  String filename = 'report.pdf',
}) async {
  final resolvedSubtitle =
      subtitle ??
      "Macrina's Kitchen and Catering · Generated ${DateTime.now().toLocal()}";

  if (kIsWeb) {
    final htmlName =
        filename.toLowerCase().endsWith('.pdf')
            ? '${filename.substring(0, filename.length - 4)}.html'
            : '$filename.html';
    openHtmlDocument(
      buildPrintableHtmlReport(
        title: title,
        subtitle: resolvedSubtitle,
        sections: sections,
      ),
      filename: htmlName,
    );
    return;
  }

  final doc = pw.Document(title: title, compress: false);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      footer:
          (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
      build: (context) {
        final widgets = <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            resolvedSubtitle,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
        ];
        for (final section in sections) {
          widgets.add(
            pw.Text(
              section.title,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(
            pw.TableHelper.fromTextArray(
              headers: section.headers,
              data: section.rows,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
            ),
          );
          widgets.add(pw.SizedBox(height: 14));
        }
        return widgets;
      },
    ),
  );

  final bytes = await doc.save();
  await printPdfBytes(bytes, name: filename);
}

/// Convenience for a single table (Action Logs / inventory style).
Future<void> printSingleTableReport({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  String? subtitle,
  String filename = 'report.pdf',
  String sectionTitle = 'Records',
}) {
  return printTabularReport(
    title: title,
    subtitle: subtitle,
    filename: filename,
    sections: [
      PrintableHtmlSection(
        title: sectionTitle,
        headers: headers,
        rows: rows,
      ),
    ],
  );
}

/// Opens already-built PDF bytes. Prefer [printTabularReport] for table data
/// so web stays responsive.
Future<void> printBuiltPdfBytes(
  Uint8List bytes, {
  String name = 'document.pdf',
}) => printPdfBytes(bytes, name: name);
