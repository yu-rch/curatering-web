import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// Opens an HTML document in a new tab for browser print / Save as PDF.
///
/// Avoids `package:pdf` [Document.save] on Flutter web, which runs on the
/// main thread and freezes the UI.
void openHtmlDocument(String html, {String filename = 'document.html'}) {
  final blob = Blob(
    [html.toJS].toJS,
    BlobPropertyBag(type: 'text/html;charset=utf-8'),
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
  Future<void>.delayed(const Duration(minutes: 2), () {
    URL.revokeObjectURL(url);
  });
}
