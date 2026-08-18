import 'package:flutter/material.dart';

import '../services/website_content_store.dart';
import 'website_rich_text.dart';

/// Editable list of CMS sections (add / reorder / delete).
class CmsSectionsEditor extends StatelessWidget {
  const CmsSectionsEditor({
    super.key,
    required this.sections,
    required this.onChanged,
    this.title = 'Extra sections',
  });

  final List<CmsSection> sections;
  final VoidCallback onChanged;
  final String title;

  void _addSection(BuildContext context) async {
    final type = await showDialog<CmsSectionType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add section'),
        children: [
          for (final t in CmsSectionType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Text(_typeLabel(t)),
            ),
        ],
      ),
    );
    if (type == null) return;
    sections.add(
      CmsSection(
        id: 'sec_${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        heading: type == CmsSectionType.heading ? 'New heading' : '',
        bodyHtml: type == CmsSectionType.richText ? '<p>New content</p>' : '',
        ctaLabel: type == CmsSectionType.cta ? 'Learn more' : '',
        ctaUrl: type == CmsSectionType.cta ? '/' : '',
      ),
    );
    onChanged();
  }

  static String _typeLabel(CmsSectionType t) => switch (t) {
    CmsSectionType.richText => 'Rich text',
    CmsSectionType.heading => 'Heading',
    CmsSectionType.image => 'Image',
    CmsSectionType.imageRow => 'Image row',
    CmsSectionType.cta => 'Call to action',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addSection(context),
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
            ),
          ],
        ),
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No extra sections yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = sections.removeAt(oldIndex);
              sections.insert(newIndex, item);
              onChanged();
            },
            itemBuilder: (context, index) {
              final s = sections[index];
              return Card(
                key: ValueKey(s.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text('${_typeLabel(s.type)} · ${s.heading.isEmpty ? s.id : s.heading}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: s.visible,
                        onChanged: (v) {
                          s.visible = v;
                          onChanged();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          sections.removeAt(index);
                          onChanged();
                        },
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          if (s.type == CmsSectionType.heading ||
                              s.type == CmsSectionType.cta ||
                              s.type == CmsSectionType.richText)
                            TextFormField(
                              initialValue: s.heading,
                              decoration: const InputDecoration(
                                labelText: 'Heading',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                s.heading = v;
                                onChanged();
                              },
                            ),
                          if (s.type == CmsSectionType.richText) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: s.bodyHtml,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Body (HTML)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                s.bodyHtml = v;
                                onChanged();
                              },
                            ),
                          ],
                          if (s.type == CmsSectionType.cta) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: s.ctaLabel,
                              decoration: const InputDecoration(
                                labelText: 'Button label',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                s.ctaLabel = v;
                                onChanged();
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: s.ctaUrl,
                              decoration: const InputDecoration(
                                labelText: 'Button URL / route',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                s.ctaUrl = v;
                                onChanged();
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: s.buttonWidth?.toStringAsFixed(0) ?? '',
                              decoration: const InputDecoration(
                                labelText: 'Button width (px, optional)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                s.buttonWidth = double.tryParse(v.trim());
                                onChanged();
                              },
                            ),
                          ],
                          if (s.type == CmsSectionType.image ||
                              s.type == CmsSectionType.imageRow)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Use live edit or media library to attach images to this section.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Public renderer for CMS sections.
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
          child: width == null
              ? button
              : SizedBox(width: width, child: button),
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
