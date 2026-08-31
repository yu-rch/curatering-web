import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Opens the platform print dialog (browser print on web).
Future<void> printPdfBytes(
  Uint8List bytes, {
  String name = 'document.pdf',
}) async {
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: name,
  );
}
