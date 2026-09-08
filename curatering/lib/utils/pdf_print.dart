import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import 'web_pdf_download.dart';

/// Opens the PDF without blocking the Flutter UI.
///
/// On web, [Printing.layoutPdf] can freeze the page while it rasterizes the
/// PDF for the browser print dialog. Opening a blob URL is much lighter.
Future<void> printPdfBytes(
  Uint8List bytes, {
  String name = 'document.pdf',
}) async {
  // Let the current frame finish (button press / loading spinner) first.
  await Future<void>.delayed(Duration.zero);

  if (kIsWeb) {
    openOrDownloadPdfBytes(bytes, name);
    return;
  }

  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: name,
  );
}
