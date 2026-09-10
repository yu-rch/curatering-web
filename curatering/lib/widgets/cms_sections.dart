import 'package:flutter/material.dart';

import '../services/website_content_store.dart';
import '../utils/website_image_utils.dart';
import 'antd_buttons.dart';
import 'website_media_picker.dart';

export 'cms_sections_view.dart' show CmsSectionsView;

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
                              s.type == CmsSectionType.imageRow) ...[
                            const SizedBox(height: 8),
                            if (s.imageBase64.trim().isNotEmpty ||
                                (s.mediaId != null &&
                                    s.mediaId!.trim().isNotEmpty))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: websiteBase64Thumbnail(
                                    s.imageBase64.trim().isNotEmpty
                                        ? s.imageBase64
                                        : null,
                                    height: 120,
                                  ),
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AntdPrimaryButton(
                                  label: 'Upload image',
                                  onPressed: () async {
                                    final b64 =
                                        await pickWebsiteImageBase64();
                                    if (b64 == null) return;
                                    String? mediaId;
                                    try {
                                      final item = await WebsiteContentStore
                                          .instance
                                          .uploadMedia(
                                            dataBase64: b64,
                                            name:
                                                'section-${DateTime.now().millisecondsSinceEpoch}',
                                          );
                                      mediaId = item.id;
                                    } catch (_) {}
                                    s.imageBase64 = b64;
                                    s.mediaId = mediaId;
                                    if (s.type == CmsSectionType.imageRow &&
                                        s.images.isEmpty) {
                                      s.images.add(
                                        CmsImageRef(
                                          base64: b64,
                                          mediaId: mediaId,
                                        ),
                                      );
                                    }
                                    onChanged();
                                  },
                                ),
                                AntdSecondaryButton(
                                  label: 'From media library',
                                  onPressed: () async {
                                    final picked =
                                        await showWebsiteMediaPicker(context);
                                    if (picked == null) return;
                                    var b64 = picked.dataBase64 ?? '';
                                    if (b64.isEmpty) {
                                      b64 =
                                          (await WebsiteContentStore.instance
                                              .resolveMediaId(picked.id)) ??
                                          '';
                                    }
                                    s.imageBase64 = b64;
                                    s.mediaId = picked.id;
                                    if (s.type == CmsSectionType.imageRow) {
                                      s.images.add(
                                        CmsImageRef(
                                          base64: b64,
                                          mediaId: picked.id,
                                        ),
                                      );
                                    }
                                    onChanged();
                                  },
                                ),
                              ],
                            ),
                          ],
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

