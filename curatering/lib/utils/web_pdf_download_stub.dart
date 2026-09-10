import 'dart:typed_data';

Object? openBlankPdfTab() => null;

void closePdfTab(Object? tab) {}

void showPdfInTab(Object? tab, Uint8List bytes, String filename) {}

void openOrDownloadPdfBytes(Uint8List bytes, String filename) {
  // Non-web platforms use the printing package dialog instead.
}
