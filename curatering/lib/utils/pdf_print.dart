import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import 'web_pdf_download.dart';

/// Opens a PDF preview tab (web) and the native Flutter print dialog.
///
/// On web, [Printing.layoutPdf] drives Print / Save as PDF. A separate tab
/// shows the raw PDF for preview. Call [openBlankPdfTab] during the click
/// gesture and pass it as [previewTab] so popup blockers don't eat the tab
/// after async PDF generation.
Future<void> printPdfBytes(
  Uint8List bytes, {
  String name = 'document.pdf',
  Object? previewTab,
}) async {
  // Let the current frame finish (button press / loading spinner) first.
  await Future<void>.delayed(Duration.zero);

  if (kIsWeb) {
    showPdfInTab(previewTab, bytes, name);
  }

  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: name,
  );
}
