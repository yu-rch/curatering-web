import 'dart:convert';

import 'package:image_picker/image_picker.dart' deferred as image_picker;

Future<String?> pickImageBase64({
  double maxWidth = 1800,
  int imageQuality = 82,
}) async {
  await image_picker.loadLibrary();
  final x = await image_picker.ImagePicker().pickImage(
    source: image_picker.ImageSource.gallery,
    maxWidth: maxWidth,
    imageQuality: imageQuality,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return base64Encode(bytes);
}

Future<List<String>> pickMultipleImagesBase64({
  double maxWidth = 1800,
  int imageQuality = 82,
}) async {
  await image_picker.loadLibrary();
  final picked = await image_picker.ImagePicker().pickMultiImage(
    maxWidth: maxWidth,
    imageQuality: imageQuality,
  );
  if (picked.isEmpty) return const [];
  final out = <String>[];
  for (final x in picked) {
    final bytes = await x.readAsBytes();
    out.add(base64Encode(bytes));
  }
  return out;
}
