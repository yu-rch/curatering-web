import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// Opens a blank tab synchronously (call during the button click gesture).
/// Returns an opaque handle for [showPdfInTab].
Object? openBlankPdfTab() {
  try {
    return window.open('about:blank', '_blank');
  } catch (_) {
    return null;
  }
}

void closePdfTab(Object? tab) {
  if (tab == null) return;
  try {
    (tab as Window).close();
  } catch (_) {}
}

/// Puts a PDF into [tab] (from [openBlankPdfTab]) or opens a new tab.
void showPdfInTab(Object? tab, Uint8List bytes, String filename) {
  final blob = Blob(
    [bytes.toJS].toJS,
    BlobPropertyBag(type: 'application/pdf'),
  );
  final url = URL.createObjectURL(blob);

  var opened = false;
  try {
    if (tab != null) {
      final win = tab as Window;
      // Navigate the pre-opened tab to the PDF blob.
      win.location.href = url;
      opened = true;
    }
  } catch (_) {
    opened = false;
  }

  if (!opened) {
    final fresh = window.open(url, '_blank');
    if (fresh == null) {
      // Last resort: trigger a download so the user still gets the file.
      final anchor =
          HTMLAnchorElement()
            ..href = url
            ..download = filename
            ..style.display = 'none';
      document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
    }
  }

  Future<void>.delayed(const Duration(minutes: 2), () {
    URL.revokeObjectURL(url);
  });
}

/// Convenience: open PDF bytes in a new tab (may be blocked after awaits).
void openOrDownloadPdfBytes(Uint8List bytes, String filename) {
  showPdfInTab(null, bytes, filename);
}
