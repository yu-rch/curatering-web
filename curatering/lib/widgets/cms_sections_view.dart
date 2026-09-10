import 'package:flutter/material.dart';

import '../services/website_content_store.dart';
import 'website_rich_text.dart';

/// Public renderer for CMS sections (no editor / image_picker dependency).
class CmsSectionsView extends StatelessWidget {
  const CmsSectionsView({super.key, required this.sections});

  final List<CmsSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in sections)
            if (s.visible) ...[
              _section(s),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _section(CmsSection s) {
    switch (s.type) {
      case CmsSectionType.heading:
        return Text(
          s.heading,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        );
      case CmsSectionType.richText:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.heading.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  s.heading,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            WebsiteRichText(
              value: s.bodyHtml,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
        );
      case CmsSectionType.cta:
        final width = s.buttonWidth;
        final button = FilledButton(
          onPressed: () {},
          child: Text(s.ctaLabel.isEmpty ? 'Learn more' : s.ctaLabel),
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: width == null ? button : SizedBox(width: width, child: button),
        );
      case CmsSectionType.image:
      case CmsSectionType.imageRow:
        return Container(
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            s.heading.isEmpty ? 'Image section' : s.heading,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        );
    }
  }
}
