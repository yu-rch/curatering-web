import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

void downloadCsvBytes(Uint8List bytes, String filename) {
  final blob = Blob(
    [bytes.toJS].toJS,
    BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = URL.createObjectURL(blob);
  final anchor =
      HTMLAnchorElement()
        ..href = url
        ..download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
  anchor.remove();
}
