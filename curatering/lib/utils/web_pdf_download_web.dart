import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// Opens a PDF in a new tab (preferred) or triggers a download.
/// Avoids `Printing.layoutPdf` on web, which can freeze the UI while rasterizing.
void openOrDownloadPdfBytes(Uint8List bytes, String filename) {
  final blob = Blob(
    [bytes.toJS].toJS,
    BlobPropertyBag(type: 'application/pdf'),
  );
  final url = URL.createObjectURL(blob);
  final opened = window.open(url, '_blank');
  if (opened == null) {
    final anchor =
        HTMLAnchorElement()
          ..href = url
          ..download = filename
          ..target = '_blank';
    document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }
  // Keep the blob URL alive briefly so the new tab can load it.
  Future<void>.delayed(const Duration(minutes: 2), () {
    URL.revokeObjectURL(url);
  });
}
