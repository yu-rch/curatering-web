import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// Opens an HTML document in a new tab for browser print / Save as PDF.
///
/// Uses `about:blank` + `document.write` (not a `blob:` URL) and wires the
/// Print / Close buttons from the opener. Blob tabs inherit the app CSP, which
/// blocks inline `onclick` / `<script>` when `script-src` has no `'unsafe-inline'`.
void openHtmlDocument(
  String html, {
  String filename = 'document.html',
  bool autoPrint = true,
}) {
  // Must open synchronously while still in the button's user-gesture stack.
  final win = window.open('about:blank', '_blank');
  if (win == null) {
    _downloadHtmlFallback(html, filename);
    return;
  }

  try {
    final doc = win.document;
    doc.open();
    doc.write(html.toJS);
    doc.close();
  } catch (_) {
    _downloadHtmlFallback(html, filename);
    return;
  }

  _wirePrintToolbar(win);

  if (autoPrint) {
    // Yield so layout paints, then open the print dialog.
    Timer(const Duration(milliseconds: 300), () {
      try {
        win.print();
      } catch (_) {}
    });
  }
}

void _wirePrintToolbar(Window win) {
  try {
    final doc = win.document;
    final printBtn = doc.querySelector('#print-btn');
    if (printBtn != null) {
      printBtn.addEventListener(
        'click',
        (Event event) {
          try {
            win.print();
          } catch (_) {}
        }.toJS,
      );
    }
    final closeBtn = doc.querySelector('#close-btn');
    if (closeBtn != null) {
      closeBtn.addEventListener(
        'click',
        (Event event) {
          try {
            win.close();
          } catch (_) {}
        }.toJS,
      );
    }
  } catch (_) {
    // Preview still usable via Ctrl/Cmd+P.
  }
}

void _downloadHtmlFallback(String html, String filename) {
  final blob = Blob(
    [html.toJS].toJS,
    BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = URL.createObjectURL(blob);
  final anchor =
      HTMLAnchorElement()
        ..href = url
        ..download = filename
        ..style.display = 'none';
  document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(const Duration(seconds: 30), () {
    URL.revokeObjectURL(url);
  });
}
