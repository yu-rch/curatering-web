import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Decode payment proof stored as raw base64 or data-URL.
Uint8List? decodePaymentProofBytes(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('data:')) {
    final comma = s.indexOf(',');
    if (comma >= 0) s = s.substring(comma + 1);
  }
  try {
    return base64Decode(s.replaceAll(RegExp(r'\s+'), ''));
  } catch (_) {
    return null;
  }
}

Widget buildPaymentProofPreview(
  String? raw, {
  double height = 200,
  String emptyLabel = 'No image',
}) {
  final bytes = decodePaymentProofBytes(raw);
  if (bytes == null || bytes.isEmpty) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(emptyLabel, style: TextStyle(color: Colors.grey.shade600)),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.memory(bytes, height: height, fit: BoxFit.contain),
  );
}
