import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> pickWebsiteImageBase64() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return base64Encode(bytes);
}

Future<List<String>> pickMultipleWebsiteImagesBase64() async {
  final picked = await ImagePicker().pickMultiImage();
  if (picked.isEmpty) return const [];
  final out = <String>[];
  for (final x in picked) {
    out.add(base64Encode(await x.readAsBytes()));
  }
  return out;
}

Widget websiteBase64Thumbnail(String? b64, {double height = 120}) {
  if (b64 == null || b64.isEmpty) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );
  }
  try {
    final normalized =
        b64
            .replaceFirst(RegExp(r'^data:image\/[^;]+;base64,'), '')
            .replaceAll('\n', '')
            .trim();
    return Image.memory(
      base64Decode(normalized),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  } catch (_) {
    return Container(
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
