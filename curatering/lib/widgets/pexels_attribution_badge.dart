import 'package:flutter/material.dart';

class PexelsAttributionBadge extends StatelessWidget {
  const PexelsAttributionBadge({
    super.key,
    required this.photographer,
  });

  final String photographer;

  @override
  Widget build(BuildContext context) {
    if (photographer.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Photo by $photographer (Pexels)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
