import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/runpod_service.dart';
import '../../utils/image_download.dart';
import '../../utils/pdf_print.dart';
import '../../utils/printable_html_report.dart';
import '../../utils/web_html_print.dart';

Future<Uint8List?> themeDesignImageBytes(
  Map<String, dynamic> themeDesign,
) async {
  final b64 =
      '${themeDesign['image'] ?? themeDesign['imageBase64'] ?? themeDesign['output'] ?? ''}'
          .trim();
  if (b64.isNotEmpty) {
    try {
      return Uint8List.fromList(base64Decode(b64));
    } catch (_) {}
  }
  final url = RunPodService.proxyImageUrlIfNeeded(
    '${themeDesign['generatedImageUrl'] ?? themeDesign['imageUrl'] ?? themeDesign['url'] ?? ''}',
  );
  if (url.isEmpty) return null;
  try {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
      return res.bodyBytes;
    }
  } catch (_) {}
  return null;
}

Future<void> showThemeDesignFullscreen(
  BuildContext context,
  Map<String, dynamic> themeDesign,
) async {
  final bytes = await themeDesignImageBytes(themeDesign);
  final url = RunPodService.proxyImageUrlIfNeeded(
    '${themeDesign['generatedImageUrl'] ?? themeDesign['imageUrl'] ?? ''}',
  );
  if (bytes == null && url.isEmpty) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder:
        (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Theme design',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  child:
                      bytes != null
                          ? Image.memory(bytes, fit: BoxFit.contain)
                          : Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
  );
}

Future<void> saveThemeDesignImageToGallery({
  required BuildContext context,
  required Map<String, dynamic> themeDesign,
  String album = 'Curatering',
}) async {
  final bytes = await themeDesignImageBytes(themeDesign);
  if (bytes == null || bytes.isEmpty) {
    throw StateError('No theme design image to save.');
  }
  await downloadImageBytes(bytes, 'curatering-theme-design.png');
}

Future<Uint8List> buildThemeDesignPdfBytes({
  required Map<String, dynamic> themeDesign,
  String eventTitle = '',
  String transactionNo = '',
}) async {
  final bytes = await themeDesignImageBytes(themeDesign);
  if (bytes == null || bytes.isEmpty) {
    throw StateError('No theme design image for PDF.');
  }
  final doc = pw.Document(compress: false);
  final image = pw.MemoryImage(bytes);
  final header = [
    if (transactionNo.trim().isNotEmpty) transactionNo.trim(),
    if (eventTitle.trim().isNotEmpty) eventTitle.trim(),
  ].join(' - ');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build:
          (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (header.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            ],
          ),
    ),
  );
  return doc.save();
}

Future<void> previewThemeDesignPdf({
  required BuildContext context,
  required Map<String, dynamic> themeDesign,
  String eventTitle = '',
  String transactionNo = '',
}) async {
  final imageBytes = await themeDesignImageBytes(themeDesign);
  if (imageBytes == null || imageBytes.isEmpty) {
    throw StateError('No theme design image for PDF.');
  }
  final header = [
    if (transactionNo.trim().isNotEmpty) transactionNo.trim(),
    if (eventTitle.trim().isNotEmpty) eventTitle.trim(),
  ].join(' - ');
  final subtitle =
      header.isEmpty
          ? "Macrina's Kitchen and Catering"
          : header;

  if (kIsWeb) {
    openHtmlDocument(
      buildPrintableHtmlImageReport(
        title: 'Theme Design',
        subtitle: subtitle,
        imageMime: 'image/png',
        imageBase64: base64Encode(imageBytes),
      ),
      filename: 'theme-design.html',
    );
    return;
  }

  final bytes = await buildThemeDesignPdfBytes(
    themeDesign: themeDesign,
    eventTitle: eventTitle,
    transactionNo: transactionNo,
  );
  await printPdfBytes(bytes, name: 'theme-design.pdf');
}
