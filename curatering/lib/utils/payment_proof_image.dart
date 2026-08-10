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

/// Full-screen zoomable lightbox for a payment proof image.
void showPaymentProofLightbox(BuildContext context, Uint8List bytes) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width * 0.92,
          height: MediaQuery.sizeOf(dialogContext).height * 0.88,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget buildPaymentProofPreview(
  String? raw, {
  double height = 200,
  String emptyLabel = 'No image',
  bool tappable = true,
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

  final image = ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.memory(
      bytes,
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    ),
  );

  if (!tappable) return image;

  return Builder(
    builder: (context) {
      return Tooltip(
        message: 'Tap to enlarge',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => showPaymentProofLightbox(context, bytes),
            child: image,
          ),
        ),
      );
    },
  );
}
