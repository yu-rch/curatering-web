import 'package:flutter/material.dart';

import '../config.dart';
import '../config/site_routes.dart';
import '../features/event_design/event_design_admin_screen.dart';
import '../services/website_content_store.dart';
import '../utils/gallery_search.dart';
import '../utils/website_image_utils.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_dialog.dart';
import '../widgets/antd_form_field.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/paginated_data_table.dart';
import '../widgets/website_media_picker.dart';
import '../widgets/website_rich_text.dart';

/// Super-admin CMS: draft/publish, media library, revisions.
class WebsiteAdminPage extends StatefulWidget {
  const WebsiteAdminPage({super.key});

  @override
  State<WebsiteAdminPage> createState() => _WebsiteAdminPageState();
}

enum _CmsSection {
  home,
  catering,
  restaurant,
  inquiry,
  gallery,
  contact,
  navigation,
  media,
  revisions,
}

class _WebsiteAdminPageState extends State<WebsiteAdminPage> {
  _CmsSection _section = _CmsSection.home;
  bool _saving = false;
  bool _publishing = false;
  bool _dirty = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WebsiteContentStore.instance.addListener(_onStore);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await WebsiteContentStore.instance.loadDraft();
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Failed to load draft: $e',
          type: AntdMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    WebsiteContentStore.instance.removeListener(_onStore);
    super.dispose();
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      await WebsiteContentStore.instance.saveDraft();
      if (!mounted) return;
      setState(() => _dirty = false);
      showAntdMessage(
        context,
        'Draft saved. Customers still see the last published version.',
        type: AntdMessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(context, 'Draft save failed: $e', type: AntdMessageType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    final noteCtrl = TextEditingController(text: 'publish');
    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Publish to live site',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This replaces the public customer website with your current draft.',
          ),
          const SizedBox(height: 12),
          AntdFieldShell(
            label: 'Revision note',
            child: AntdOutlineInput(controller: noteCtrl, hintText: 'Optional note'),
          ),
        ],
      ),
      actions: [
        AntdCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        AntdPrimaryButton(
          label: 'Publish',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true || !mounted) return;

    setState(() => _publishing = true);
    try {
      await WebsiteContentStore.instance.publish(
        note: note.isEmpty ? 'publish' : note,
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      showAntdMessage(
        context,
        'Published. Customer site will show the new content.',
        type: AntdMessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(context, 'Publish failed: $e', type: AntdMessageType.error);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _previewDraft() {
    Navigator.of(context).pushNamed('/website');
  }

  String get _sectionTitle {
    switch (_section) {
      case _CmsSection.home:
        return 'Homepage';
      case _CmsSection.catering:
        return 'Catering page';
      case _CmsSection.restaurant:
        return 'Restaurant page';
      case _CmsSection.inquiry:
        return 'Inquiry page';
      case _CmsSection.gallery:
        return 'Gallery';
      case _CmsSection.contact:
        return 'Contact & footer';
      case _CmsSection.navigation:
        return 'Navigation';
      case _CmsSection.media:
        return 'Media library';
      case _CmsSection.revisions:
        return 'Revisions';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = WebsiteContentStore.instance;
    final publishedLabel = store.publishedAt == null
        ? 'Never published'
        : 'Published ${store.publishedAt}';

    return AppScaffold(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CmsSideNav(
                selected: _section,
                onSelect: (s) => setState(() => _section = s),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Website CMS · $_sectionTitle',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$publishedLabel · Editing draft',
                                  style: const TextStyle(
                                    color: AntdTokens.labelMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              if (isStaffSiteHost) {
                                redirectToSiteOrigin(customerSiteOrigin, '/');
                              } else {
                                Navigator.of(
                                  context,
                                ).pushNamed(customerRoute('/'));
                              }
                            },
                            icon: const Icon(Icons.public, size: 18),
                            label: const Text('Live site'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _previewDraft,
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            label: const Text('Preview draft'),
                          ),
                          const SizedBox(width: 8),
                          AntdSecondaryButton(
                            label: _dirty ? 'Save draft *' : 'Save draft',
                            onPressed: _saving || _publishing ? null : _saveDraft,
                          ),
                          const SizedBox(width: 8),
                          AntdPrimaryButton(
                            label: 'Publish',
                            loading: _publishing,
                            onPressed:
                                _saving || _publishing ? null : _publish,
                          ),
                        ],
                      ),
                    ),
                    if (_dirty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Material(
                          color: AntdTokens.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AntdTokens.warning,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Unsaved local edits. Save draft, then Publish to update the customer site.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: store,
                        builder: (context, _) {
                          switch (_section) {
                            case _CmsSection.home:
                              return _HomepageEditor(onChanged: _markDirty);
                            case _CmsSection.catering:
                              return _SimplePageEditor(
                                titleLabel: 'Catering page title',
                                titleValue: store.cateringPageTitle,
                                onTitle: (v) {
                                  store.cateringPageTitle = v;
                                  _markDirty();
                                },
                                subtitleLabel: 'Subtitle',
                                subtitleValue: store.cateringPageSubtitle,
                                onSubtitle: (v) {
                                  store.cateringPageSubtitle = v;
                                  _markDirty();
                                },
                              );
                            case _CmsSection.restaurant:
                              return _SimplePageEditor(
                                titleLabel: 'Restaurant page title',
                                titleValue: store.restaurantPageTitle,
                                onTitle: (v) {
                                  store.restaurantPageTitle = v;
                                  _markDirty();
                                },
                                subtitleLabel: 'Subtitle',
                                subtitleValue: store.restaurantPageSubtitle,
                                onSubtitle: (v) {
                                  store.restaurantPageSubtitle = v;
                                  _markDirty();
                                },
                              );
                            case _CmsSection.inquiry:
                              return _InquiryEditor(onChanged: _markDirty);
                            case _CmsSection.gallery:
                              return _GalleryEditor(onChanged: _markDirty);
                            case _CmsSection.contact:
                              return _ContactEditor(onChanged: _markDirty);
                            case _CmsSection.navigation:
                              return _NavigationEditor(onChanged: _markDirty);
                            case _CmsSection.media:
                              return const _MediaLibraryPanel();
                            case _CmsSection.revisions:
                              return const _RevisionsPanel();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}

class _CmsSideNav extends StatelessWidget {
  const _CmsSideNav({required this.selected, required this.onSelect});

  final _CmsSection selected;
  final ValueChanged<_CmsSection> onSelect;

  static const _items = <(_CmsSection, String, IconData)>[
    (_CmsSection.home, 'Homepage', Icons.home_outlined),
    (_CmsSection.catering, 'Catering', Icons.ramen_dining_outlined),
    (_CmsSection.restaurant, 'Restaurant', Icons.restaurant_outlined),
    (_CmsSection.inquiry, 'Inquiry', Icons.mail_outline),
    (_CmsSection.gallery, 'Gallery', Icons.photo_library_outlined),
    (_CmsSection.contact, 'Contact & footer', Icons.contact_page_outlined),
    (_CmsSection.navigation, 'Navigation', Icons.menu_outlined),
    (_CmsSection.media, 'Media', Icons.perm_media_outlined),
    (_CmsSection.revisions, 'Revisions', Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: SizedBox(
        width: 220,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Content',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AntdTokens.labelMuted,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final item in _items)
              ListTile(
                dense: true,
                selected: selected == item.$1,
                selectedTileColor: AntdTokens.brandPrimary.withValues(
                  alpha: 0.18,
                ),
                leading: Icon(item.$3, size: 20),
                title: Text(item.$2, style: const TextStyle(fontSize: 14)),
                onTap: () => onSelect(item.$1),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _cmsPad({required Widget child}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: child,
      ),
    ),
  );
}

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12, top: 8),
  child: Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  ),
);

class _CmsTextField extends StatefulWidget {
  const _CmsTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<_CmsTextField> createState() => _CmsTextFieldState();
}

class _CmsTextFieldState extends State<_CmsTextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CmsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AntdFieldShell(
      label: widget.label,
      child: AntdOutlineInput(
        controller: _ctrl,
        maxLines: widget.maxLines,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _SimplePageEditor extends StatelessWidget {
  const _SimplePageEditor({
    required this.titleLabel,
    required this.titleValue,
    required this.onTitle,
    required this.subtitleLabel,
    required this.subtitleValue,
    required this.onSubtitle,
  });

  final String titleLabel;
  final String titleValue;
  final ValueChanged<String> onTitle;
  final String subtitleLabel;
  final String subtitleValue;
  final ValueChanged<String> onSubtitle;

  @override
  Widget build(BuildContext context) {
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Page text'),
          _CmsTextField(label: titleLabel, value: titleValue, onChanged: onTitle),
          const SizedBox(height: 12),
          _CmsTextField(
            label: subtitleLabel,
            value: subtitleValue,
            onChanged: onSubtitle,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _HomepageEditor extends StatelessWidget {
  const _HomepageEditor({required this.onChanged});
  final VoidCallback onChanged;

  Future<void> _pickHero(BuildContext context) async {
    final w = WebsiteContentStore.instance;
    final picked = await showWebsiteMediaPicker(context);
    if (picked == null) return;
    w.homeHeroMediaId = picked.id;
    w.homeHeroImageBase64 = picked.dataBase64 ?? '';
    if (w.homeHeroImageBase64.isEmpty) {
      final b64 = await w.resolveMediaId(picked.id);
      w.homeHeroImageBase64 = b64 ?? '';
    }
    w.touch();
    onChanged();
  }

  Future<void> _addListImage(
    BuildContext context, {
    required List<String> base64List,
    required List<String?> mediaIds,
  }) async {
    final w = WebsiteContentStore.instance;
    final picked = await showWebsiteMediaPicker(context);
    if (picked == null) return;
    var b64 = picked.dataBase64 ?? '';
    if (b64.isEmpty) b64 = (await w.resolveMediaId(picked.id)) ?? '';
    base64List.add(b64);
    mediaIds.add(picked.id);
    w.touch();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Hero'),
          websiteBase64Thumbnail(w.homeHeroImageBase64, height: 160),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AntdSecondaryButton(
              label: 'Choose hero image',
              onPressed: () => _pickHero(context),
            ),
          ),
          const SizedBox(height: 16),
          _CmsTextField(
            label: 'Red banner text',
            value: w.redBannerText,
            onChanged: (v) {
              w.redBannerText = v;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
          _sectionTitle('Latest event'),
          _CmsTextField(
            label: 'Section label',
            value: w.latestEventSectionLabel,
            onChanged: (v) {
              w.latestEventSectionLabel = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Title',
            value: w.latestEventTitle,
            onChanged: (v) {
              w.latestEventTitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Subtitle',
            value: w.latestEventSubtitle,
            onChanged: (v) {
              w.latestEventSubtitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          AntdFieldShell(
            label: 'Body (rich text)',
            child: InkWell(
              onTap: () async {
                final next = await showWebsiteRichTextEditor(
                  context: context,
                  title: 'Latest event body',
                  initialValue: w.latestEventBody,
                );
                if (next == null) return;
                w.latestEventBody = next;
                w.touch();
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  w.latestEventBody.replaceAll(RegExp(r'<[^>]+>'), ' ').trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AntdSecondaryButton(
              label: 'Add collage image',
              onPressed: () => _addListImage(
                context,
                base64List: w.latestEventCollageBase64,
                mediaIds: w.latestEventCollageMediaIds,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Popular dishes'),
          _CmsTextField(
            label: 'Section label',
            value: w.popularDishesSectionLabel,
            onChanged: (v) {
              w.popularDishesSectionLabel = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Subtitle',
            value: w.popularDishesSubtitle,
            onChanged: (v) {
              w.popularDishesSubtitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AntdSecondaryButton(
              label: 'Add dish image',
              onPressed: () => _addListImage(
                context,
                base64List: w.popularDishImageBase64,
                mediaIds: w.popularDishMediaIds,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Event designs'),
          _CmsTextField(
            label: 'Section label',
            value: w.eventDesignsSectionLabel,
            onChanged: (v) {
              w.eventDesignsSectionLabel = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Subtitle',
            value: w.eventDesignsSubtitle,
            onChanged: (v) {
              w.eventDesignsSubtitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AntdSecondaryButton(
              label: 'Add design image',
              onPressed: () => _addListImage(
                context,
                base64List: w.eventDesignImageBase64,
                mediaIds: w.eventDesignMediaIds,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InquiryEditor extends StatelessWidget {
  const _InquiryEditor({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Inquiry page'),
          _CmsTextField(
            label: 'Page title',
            value: w.inquiryPageTitle,
            onChanged: (v) {
              w.inquiryPageTitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _CmsTextField(
            label: 'Subtitle',
            value: w.inquiryPageSubtitle,
            onChanged: (v) {
              w.inquiryPageSubtitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
          AntdSecondaryButton(
            label: 'Manage event design options',
            onPressed: () {
              showAntdModal<void>(
                context: context,
                title: 'Event design options',
                maxWidth: 800,
                body: SizedBox(
                  height: 560,
                  child: EventDesignAdminScreen(apiBase: apiBaseUrl),
                ),
                actions: [
                  AntdPrimaryButton(
                    label: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GalleryEditor extends StatelessWidget {
  const _GalleryEditor({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CmsTextField(
            label: 'Gallery title',
            value: w.galleryTitle,
            onChanged: (v) {
              w.galleryTitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _CmsTextField(
            label: 'Intro',
            value: w.galleryIntro,
            maxLines: 3,
            onChanged: (v) {
              w.galleryIntro = v;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
          _sectionTitle('Categories'),
          for (final cat in w.galleryCategories) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CmsTextField(
                      label: 'Category label',
                      value: cat.label,
                      onChanged: (v) {
                        cat.label = v;
                        onChanged();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${cat.images.length} image(s)',
                      style: const TextStyle(color: AntdTokens.labelMuted),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AntdSecondaryButton(
                        label: 'Add images from library',
                        onPressed: () async {
                          final picked = await showWebsiteMediaPicker(context);
                          if (picked == null) return;
                          var b64 = picked.dataBase64 ?? '';
                          if (b64.isEmpty) {
                            b64 =
                                (await WebsiteContentStore.instance
                                    .resolveMediaId(picked.id)) ??
                                '';
                          }
                          cat.images.add(
                            GalleryImageData(
                              id: 'img_${picked.id}',
                              mediaId: picked.id,
                              imageBase64: b64,
                              tags: List.from(cat.defaultTagsForUpload),
                            ),
                          );
                          w.touch();
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Text(
            galleryTagsHint(),
            style: const TextStyle(fontSize: 12, color: AntdTokens.labelMuted),
          ),
        ],
      ),
    );
  }
}

class _ContactEditor extends StatelessWidget {
  const _ContactEditor({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CmsTextField(
            label: 'Contact title',
            value: w.contactTitle,
            onChanged: (v) {
              w.contactTitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Banner text',
            value: w.contactBannerText,
            onChanged: (v) {
              w.contactBannerText = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Reach us label',
            value: w.contactReachUsLabel,
            onChanged: (v) {
              w.contactReachUsLabel = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          AntdFieldShell(
            label: 'Page intro (rich text)',
            child: InkWell(
              onTap: () async {
                final next = await showWebsiteRichTextEditor(
                  context: context,
                  title: 'Contact intro',
                  initialValue: w.contactPageIntro,
                );
                if (next == null) return;
                w.contactPageIntro = next;
                w.touch();
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  w.contactPageIntro
                      .replaceAll(RegExp(r'<[^>]+>'), ' ')
                      .trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Facebook label',
            value: w.contactFacebook,
            onChanged: (v) {
              w.contactFacebook = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Facebook URL',
            value: w.contactFacebookUrl,
            onChanged: (v) {
              w.contactFacebookUrl = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Address',
            value: w.contactAddress,
            maxLines: 2,
            onChanged: (v) {
              w.contactAddress = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Hours',
            value: w.contactHours,
            onChanged: (v) {
              w.contactHours = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Phone',
            value: w.contactPhone,
            onChanged: (v) {
              w.contactPhone = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Email',
            value: w.contactEmail,
            onChanged: (v) {
              w.contactEmail = v;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
          _sectionTitle('Footer'),
          _CmsTextField(
            label: 'Copyright',
            value: w.footerCopyright,
            onChanged: (v) {
              w.footerCopyright = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Privacy label',
            value: w.footerPrivacyLabel,
            onChanged: (v) {
              w.footerPrivacyLabel = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          AntdFieldShell(
            label: 'Privacy body (rich text)',
            child: InkWell(
              onTap: () async {
                final next = await showWebsiteRichTextEditor(
                  context: context,
                  title: 'Privacy policy',
                  initialValue: w.footerPrivacyBody,
                );
                if (next == null) return;
                w.footerPrivacyBody = next;
                w.touch();
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  w.footerPrivacyBody
                      .replaceAll(RegExp(r'<[^>]+>'), ' ')
                      .trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationEditor extends StatelessWidget {
  const _NavigationEditor({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Top navigation'),
          _CmsTextField(
            label: 'Brand label',
            value: w.navBrandLabel,
            onChanged: (v) {
              w.navBrandLabel = v;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _MediaLibraryPanel extends StatefulWidget {
  const _MediaLibraryPanel();

  @override
  State<_MediaLibraryPanel> createState() => _MediaLibraryPanelState();
}

class _MediaLibraryPanelState extends State<_MediaLibraryPanel> {
  List<WebsiteMediaItem> _items = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final items = await WebsiteContentStore.instance.listMedia(query: _query);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        showAntdMessage(context, 'Media load failed: $e', type: AntdMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final b64 = await pickWebsiteImageBase64();
    if (b64 == null) return;
    try {
      await WebsiteContentStore.instance.uploadMedia(dataBase64: b64);
      await _reload();
      if (mounted) {
        showAntdMessage(context, 'Uploaded', type: AntdMessageType.success);
      }
    } catch (e) {
      if (mounted) {
        showAntdMessage(context, 'Upload failed: $e', type: AntdMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search media',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _query = v,
                  onSubmitted: (_) => _reload(),
                ),
              ),
              const SizedBox(width: 8),
              AntdSecondaryButton(label: 'Search', onPressed: _reload),
              const SizedBox(width: 8),
              AntdPrimaryButton(label: 'Upload', onPressed: _upload),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : PagedDataTable(
                  title: 'Media library',
                  enableSearch: false,
                  enableCsv: false,
                  enablePrint: false,
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('MIME')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('Tags')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final m in _items)
                      DataRow(
                        cells: [
                          DataCell(Text(m.name)),
                          DataCell(Text(m.mime)),
                          DataCell(Text('${(m.byteSize / 1024).toStringAsFixed(1)} KB')),
                          DataCell(Text(m.tags.join(', '))),
                          DataCell(
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await showAntdModal<bool>(
                                  context: context,
                                  title: 'Delete media',
                                  body: Text('Delete ${m.name}?'),
                                  actions: [
                                    AntdCancelButton(
                                      label: 'Cancel',
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                    ),
                                    AntdPrimaryButton(
                                      label: 'Delete',
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                    ),
                                  ],
                                );
                                if (ok != true) return;
                                await WebsiteContentStore.instance
                                    .deleteMedia(m.id);
                                await _reload();
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class _RevisionsPanel extends StatefulWidget {
  const _RevisionsPanel();

  @override
  State<_RevisionsPanel> createState() => _RevisionsPanelState();
}

class _RevisionsPanelState extends State<_RevisionsPanel> {
  List<WebsiteRevisionItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final items = await WebsiteContentStore.instance.listRevisions();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Revisions load failed: $e',
          type: AntdMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: PagedDataTable(
        title: 'Publish history',
        enableSearch: false,
        enableCsv: false,
        enablePrint: false,
        columns: const [
          DataColumn(label: Text('When')),
          DataColumn(label: Text('Note')),
          DataColumn(label: Text('By')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final r in _items)
            DataRow(
              cells: [
                DataCell(Text('${r.createdAt ?? ''}')),
                DataCell(Text(r.note ?? '')),
                DataCell(Text(r.publishedBy ?? '')),
                DataCell(
                  TextButton(
                    onPressed: () async {
                      final ok = await showAntdModal<bool>(
                        context: context,
                        title: 'Restore revision',
                        body: const Text(
                          'Load this snapshot into the draft? You still need to Publish to go live.',
                        ),
                        actions: [
                          AntdCancelButton(
                            label: 'Cancel',
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          AntdPrimaryButton(
                            label: 'Restore to draft',
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      );
                      if (ok != true) return;
                      try {
                        await WebsiteContentStore.instance.restoreRevision(
                          r.id,
                        );
                        if (!context.mounted) return;
                        showAntdMessage(
                          context,
                          'Restored to draft',
                          type: AntdMessageType.success,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        showAntdMessage(
                          context,
                          'Restore failed: $e',
                          type: AntdMessageType.error,
                        );
                      }
                    },
                    child: const Text('Restore'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
