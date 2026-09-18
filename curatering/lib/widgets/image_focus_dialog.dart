import 'package:flutter/material.dart';

import '../utils/image_cache.dart';

/// Fullscreen-ish dialog: image on the left, title/details on the right
/// (stacked vertically below 700px).
void showImageFocusDialog(
  BuildContext context, {
  required String? imageBase64,
  String? imageUrl,
  required String title,
  String? description,
  List<MapEntry<String, String>> detailBlocks = const [],
  List<Widget>? actions,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final hasB64 = imageBase64 != null && imageBase64.trim().isNotEmpty;
      final networkUrl = (imageUrl ?? '').trim();
      final hasUrl = networkUrl.isNotEmpty;
      final hasImage = hasB64 || hasUrl;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 700;
                      final imageWidget =
                          hasImage
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 320,
                                  ),
                                  child:
                                      hasUrl
                                          ? Image.network(
                                            networkUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (_, __, ___) =>
                                                    hasB64
                                                        ? CachedBase64Image(
                                                          base64String:
                                                              imageBase64,
                                                          fit: BoxFit.contain,
                                                        )
                                                        : const Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          size: 48,
                                                        ),
                                          )
                                          : CachedBase64Image(
                                            base64String: imageBase64,
                                            fit: BoxFit.contain,
                                          ),
                                ),
                              )
                              : Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.image_outlined, size: 48),
                                ),
                              );

                      final details = _ImageFocusDetails(
                        title: title,
                        description: description,
                        detailBlocks: detailBlocks,
                      );

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            imageWidget,
                            const SizedBox(height: 16),
                            details,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 360, child: imageWidget),
                          const SizedBox(width: 22),
                          Expanded(child: details),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (actions != null && actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ImageFocusDetails extends StatelessWidget {
  const _ImageFocusDetails({
    required this.title,
    this.description,
    required this.detailBlocks,
  });

  final String title;
  final String? description;
  final List<MapEntry<String, String>> detailBlocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            description!,
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.35,
              fontSize: 15,
            ),
          ),
        ],
        for (final block in detailBlocks) ...[
          const SizedBox(height: 16),
          Text(
            block.key,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            block.value,
            style: TextStyle(color: Colors.grey.shade800, height: 1.35),
          ),
        ],
      ],
    );
  }
}
