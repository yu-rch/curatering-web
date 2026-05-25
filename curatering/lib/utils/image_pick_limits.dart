import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/antd_message.dart';

const int kMaxImageAttachmentBytes = 25 * 1024 * 1024;

String imageAttachmentTooLargeMessage(int maxMb) =>
    'Each image must be $maxMb MB or smaller.';

Future<List<String>> pickImagesBase64({
  required BuildContext context,
  bool allowMultiple = true,
  int maxBytes = kMaxImageAttachmentBytes,
  int imageQuality = 88,
  int? maxWidth,
}) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (allowMultiple) {
    files = await picker.pickMultiImage(
      imageQuality: imageQuality,
      maxWidth: maxWidth?.toDouble(),
    );
  } else {
    final one = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
      maxWidth: maxWidth?.toDouble(),
    );
    files = one == null ? const <XFile>[] : [one];
  }
  if (files.isEmpty) return const [];

  final out = <String>[];
  var skipped = 0;
  for (final file in files) {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      skipped++;
      continue;
    }
    out.add(base64Encode(bytes));
  }
  if (skipped > 0 && context.mounted) {
    showAntdMessage(
      context,
      imageAttachmentTooLargeMessage(maxBytes ~/ (1024 * 1024)),
      type: AntdMessageType.warning,
    );
  }
  return out;
}
