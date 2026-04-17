// Stub implementation used for non-web platforms.
// This keeps the code compile-time compatible in Flutter desktop/mobile builds.

import 'dart:async';

// NOTE: The stub classes intentionally do not provide real file access.
// Code should guard usage with `kIsWeb` to avoid running these on non-web.

class File {
  const File();
}

class FileUploadInputElement {
  String accept = '';
  bool multiple = false;

  void click() {}

  List<File>? get files => null;

  Stream<Object> get onChange => const Stream<Object>.empty();
}

class FileReader {
  Object? result;

  void readAsArrayBuffer(File file) {}

  Stream<Object> get onLoad => const Stream<Object>.empty();
}
