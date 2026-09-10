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

  // Prefer a real download — more reliable than relying on the browser PDF
  // viewer print UI (and avoids popup blockers swallowing blob tabs).
  final anchor =
      HTMLAnchorElement()
        ..href = url
        ..download = filename
        ..rel = 'noopener'
        ..style.display = 'none';
  document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Also try opening a preview tab when popups are allowed.
  final opened = window.open(url, '_blank');
  if (opened == null) {
    // Download already triggered above.
  }

  Future<void>.delayed(const Duration(minutes: 2), () {
    URL.revokeObjectURL(url);
  });
}
