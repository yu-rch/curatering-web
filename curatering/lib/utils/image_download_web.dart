import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<void> downloadImageBytes(Uint8List bytes, String filename) async {
  final blob = Blob([bytes.toJS].toJS);
  final url = URL.createObjectURL(blob);
  final anchor =
      HTMLAnchorElement()
        ..href = url
        ..download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
  anchor.remove();
}
