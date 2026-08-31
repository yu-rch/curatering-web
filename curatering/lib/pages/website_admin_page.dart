import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../config/site_routes.dart';
import '../config/site_open_tab_stub.dart'
    if (dart.library.html) '../config/site_open_tab_web.dart';
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
import '../widgets/cms_sections.dart';
import '../widgets/completed_event_gallery_picker.dart';
import '../widgets/mobile_ui_cms_editor.dart';
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
  brand,
  catering,
  restaurant,
  inquiry,
  gallery,
  contact,
  navigation,
  pages,
  mobileApp,
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
    setState(() => _dirty = true);
  }

  @override
  void dispose() {
    WebsiteContentStore.instance.removeListener(_onStore);
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Save draft?',
      body: const Text(
        'Save your current changes to the draft? Customers will still see the last published version until you publish.',
      ),
      actions: [
        AntdCancelButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        AntdPrimaryButton(
          label: 'Save draft',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true || !mounted) return;

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
    final store = WebsiteContentStore.instance;
    final changes = store.pendingPublishChanges();
    final noteCtrl = TextEditingController(text: 'publish');

    final ok = await showAntdModal<bool>(
      context: context,
      title: 'Publish to live site',
      maxWidth: 640,
      scrollBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This replaces the public customer website with your current draft.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Changes to be published:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (changes.isEmpty)
            const Text('No detectable changes from the live site.')
          else
            ...changes.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
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

  void _openLiveSite() {
    if (kIsWeb) {
      openAppRouteInNewTab(customerSiteOrigin, '/');
      return;
    }
    redirectToSiteOrigin(customerSiteOrigin, '/');
  }

  void _previewDraft() {
    Navigator.of(context).pushNamed(
      '/website',
      arguments: const {'returnRoute': '/website-admin'},
    );
  }

  String get _sectionTitle {
    switch (_section) {
      case _CmsSection.home:
        return 'Homepage';
      case _CmsSection.brand:
        return 'Brand';
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
      case _CmsSection.pages:
        return 'Custom pages';
      case _CmsSection.mobileApp:
        return 'Mobile App';
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
    final narrow = MediaQuery.sizeOf(context).width < 700;

    Widget editorBody() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (narrow)
                            IconButton(
                              tooltip: 'Sections',
                              onPressed: () async {
                                final next = await showModalBottomSheet<_CmsSection>(
                                  context: context,
                                  builder: (ctx) {
                                    return SafeArea(
                                      child: ListView(
                                        shrinkWrap: true,
                                        children: [
                                          for (final item in _CmsSideNav._items)
                                            ListTile(
                                              leading: Icon(item.$3),
                                              title: Text(item.$2),
                                              selected: _section == item.$1,
                                              onTap: () => Navigator.pop(ctx, item.$1),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                                if (next != null) {
                                  setState(() => _section = next);
                                }
                              },
                              icon: const Icon(Icons.menu),
                            ),
                          Expanded(
                            child: Text(
                              'Website CMS · $_sectionTitle',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
                const SizedBox(width: 12),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _openLiveSite,
                        icon: const Icon(Icons.public, size: 18),
                        label: const Text('Live site'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _previewDraft,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Preview draft'),
                      ),
                      AntdSecondaryButton(
                        label: _dirty ? 'Save draft *' : 'Save draft',
                        onPressed: _saving || _publishing ? null : _saveDraft,
                      ),
                      AntdPrimaryButton(
                        label: 'Publish',
                        loading: _publishing,
                        onPressed: _saving || _publishing ? null : _publish,
                      ),
                    ],
                  ),
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
                      Icon(Icons.info_outline, color: AntdTokens.warning),
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
                  case _CmsSection.brand:
                    return _BrandEditor(onChanged: _markDirty);
                  case _CmsSection.catering:
                    return _SimplePageEditor(
                      pageKey: 'catering',
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
                      onChanged: _markDirty,
                    );
                  case _CmsSection.restaurant:
                    return _SimplePageEditor(
                      pageKey: 'restaurant',
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
                      onChanged: _markDirty,
                    );
                  case _CmsSection.inquiry:
                    return _InquiryEditor(onChanged: _markDirty);
                  case _CmsSection.gallery:
                    return _GalleryEditor(onChanged: _markDirty);
                  case _CmsSection.contact:
                    return _ContactEditor(onChanged: _markDirty);
                  case _CmsSection.navigation:
                    return _NavigationEditor(onChanged: _markDirty);
                  case _CmsSection.pages:
                    return _CustomPagesEditor(onChanged: _markDirty);
                  case _CmsSection.mobileApp:
                    return _cmsPad(
                      child: MobileUiCmsEditor(onChanged: _markDirty),
                    );
                  case _CmsSection.media:
                    return const _MediaLibraryPanel();
                  case _CmsSection.revisions:
                    return const _RevisionsPanel();
                }
              },
            ),
          ),
        ],
      );
    }

    return AppScaffold(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : narrow
          ? editorBody()
          : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CmsSideNav(
                selected: _section,
                onSelect: (s) => setState(() => _section = s),
              ),
              Expanded(child: editorBody()),
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
    (_CmsSection.brand, 'Brand', Icons.palette_outlined),
    (_CmsSection.catering, 'Catering', Icons.ramen_dining_outlined),
    (_CmsSection.restaurant, 'Restaurant', Icons.restaurant_outlined),
    (_CmsSection.inquiry, 'Inquiry', Icons.mail_outline),
    (_CmsSection.gallery, 'Gallery', Icons.photo_library_outlined),
    (_CmsSection.contact, 'Contact & footer', Icons.contact_page_outlined),
    (_CmsSection.navigation, 'Navigation', Icons.menu_outlined),
    (_CmsSection.pages, 'Pages', Icons.article_outlined),
    (_CmsSection.mobileApp, 'Mobile App', Icons.phone_android_outlined),
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
    required this.pageKey,
    required this.titleLabel,
    required this.titleValue,
    required this.onTitle,
    required this.subtitleLabel,
    required this.subtitleValue,
    required this.onSubtitle,
    required this.onChanged,
  });

  final String pageKey;
  final String titleLabel;
  final String titleValue;
  final ValueChanged<String> onTitle;
  final String subtitleLabel;
  final String subtitleValue;
  final ValueChanged<String> onSubtitle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final extras =
        WebsiteContentStore.instance.pageExtraSections[pageKey] ?? <CmsSection>[];
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
          const SizedBox(height: 24),
          CmsSectionsEditor(sections: extras, onChanged: onChanged),
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
          _sectionTitle('Page layout'),
          Text(
            'Reorder, hide, or show homepage sections. Extra CMS sections stay in Extra sections.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: w.homeLayout.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = w.homeLayout.removeAt(oldIndex);
              w.homeLayout.insert(newIndex, item);
              onChanged();
            },
            itemBuilder: (context, index) {
              final block = w.homeLayout[index];
              return ListTile(
                key: ValueKey(block.id),
                leading: const Icon(Icons.drag_handle),
                title: Text(block.label.isEmpty ? block.id : block.label),
                trailing: Switch(
                  value: block.visible,
                  onChanged: (v) {
                    block.visible = v;
                    w.touch();
                    onChanged();
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _sectionTitle('Side panel copy'),
          _CmsTextField(
            label: 'Kitchen panel title',
            value: w.kitchenPanelTitle,
            onChanged: (v) {
              w.kitchenPanelTitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Kitchen panel subtitle',
            value: w.kitchenPanelSubtitle,
            onChanged: (v) {
              w.kitchenPanelSubtitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Catering panel title',
            value: w.cateringPanelTitle,
            onChanged: (v) {
              w.cateringPanelTitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Catering panel subtitle',
            value: w.cateringPanelSubtitle,
            onChanged: (v) {
              w.cateringPanelSubtitle = v;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          CmsSectionsEditor(
            sections: w.pageExtraSections['home'] ?? <CmsSection>[],
            onChanged: onChanged,
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
          _sectionTitle('Categories (long-press to rearrange)'),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: w.galleryCategories.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = w.galleryCategories.removeAt(oldIndex);
              w.galleryCategories.insert(newIndex, item);
              onChanged();
            },
            itemBuilder: (context, index) {
              final cat = w.galleryCategories[index];
              return Card(
                key: ValueKey(cat.id),
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
                          label: 'Add images',
                          onPressed: () async {
                            final picked =
                                await showCompletedEventGalleryPicker(context);
                            if (picked == null || picked.isEmpty) return;
                            for (final b64 in picked) {
                              cat.images.add(
                                GalleryImageData(
                                  id:
                                      'img_${DateTime.now().microsecondsSinceEpoch}_${cat.images.length}',
                                  imageBase64: b64,
                                  tags: List.from(cat.defaultTagsForUpload),
                                ),
                              );
                            }
                            w.touch();
                            onChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Text(
            galleryTagsHint(),
            style: const TextStyle(fontSize: 12, color: AntdTokens.labelMuted),
          ),
        ],
      ),
    );
  }
}

class _BrandEditor extends StatelessWidget {
  const _BrandEditor({required this.onChanged});
  final VoidCallback onChanged;

  Future<void> _pickLogo(
    BuildContext context, {
    required void Function(String b64) apply,
  }) async {
    final w = WebsiteContentStore.instance;
    final picked = await showWebsiteMediaPicker(context);
    if (picked == null) return;
    var b64 = picked.dataBase64 ?? '';
    if (b64.isEmpty) b64 = (await w.resolveMediaId(picked.id)) ?? '';
    if (b64.isEmpty) return;
    apply(b64);
    w.touch();
    onChanged();
  }

  Color? _parseHex(String raw) {
    var hex = raw.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final n = int.tryParse(hex, radix: 16);
    return n == null ? null : Color(n);
  }

  Widget _colorField({
    required String label,
    required String value,
    required ValueChanged<String> onHex,
  }) {
    final color = _parseHex(value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CmsTextField(
            label: label,
            value: value,
            onChanged: onHex,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Logos'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Header logo',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    websiteBase64Thumbnail(w.headerLogoBase64, height: 88),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AntdSecondaryButton(
                          label: 'Upload header logo',
                          onPressed: () => _pickLogo(
                            context,
                            apply: (b64) => w.headerLogoBase64 = b64,
                          ),
                        ),
                        if ((w.headerLogoBase64 ?? '').isNotEmpty)
                          TextButton(
                            onPressed: () {
                              w.headerLogoBase64 = null;
                              w.touch();
                              onChanged();
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Login logo',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    websiteBase64Thumbnail(w.loginLogoBase64, height: 88),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AntdSecondaryButton(
                          label: 'Upload login logo',
                          onPressed: () => _pickLogo(
                            context,
                            apply: (b64) => w.loginLogoBase64 = b64,
                          ),
                        ),
                        if ((w.loginLogoBase64 ?? '').isNotEmpty)
                          TextButton(
                            onPressed: () {
                              w.loginLogoBase64 = null;
                              w.touch();
                              onChanged();
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Site colors'),
          _colorField(
            label: 'Primary color',
            value: w.sitePrimaryColor,
            onHex: (v) {
              w.sitePrimaryColor = v.trim().isEmpty ? '#1E1E1E' : v.trim();
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          _colorField(
            label: 'Accent color',
            value: w.siteAccentColor,
            onHex: (v) {
              w.siteAccentColor = v.trim().isEmpty ? '#FFC024' : v.trim();
              onChanged();
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle('Owner blurb'),
          AntdFieldShell(
            label: 'About the business (rich text)',
            child: InkWell(
              onTap: () async {
                final next = await showWebsiteRichTextEditor(
                  context: context,
                  title: 'Owner blurb',
                  initialValue: w.ownerBlurb,
                );
                if (next == null) return;
                w.ownerBlurb = next;
                w.touch();
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  w.ownerBlurb.replaceAll(RegExp(r'<[^>]+>'), ' ').trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _CmsTextField(
            label: 'Nav brand label',
            value: w.navBrandLabel,
            onChanged: (v) {
              w.navBrandLabel = v;
              onChanged();
            },
          ),
          const SizedBox(height: 20),
          _FaqEditor(onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FaqEditor extends StatelessWidget {
  const _FaqEditor({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('FAQ')),
            TextButton.icon(
              onPressed: () {
                w.faqItems.add(
                  CmsFaqItem(
                    question: 'New question',
                    answer: 'Answer goes here.',
                  ),
                );
                w.touch();
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add FAQ'),
            ),
          ],
        ),
        if (w.faqItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'No FAQ items yet.',
              style: TextStyle(color: AntdTokens.labelMuted),
            ),
          ),
        for (var i = 0; i < w.faqItems.length; i++)
          Card(
            key: ValueKey('faq_$i'),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FAQ ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () {
                          w.faqItems.removeAt(i);
                          w.touch();
                          onChanged();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  _CmsTextField(
                    label: 'Question',
                    value: w.faqItems[i].question,
                    onChanged: (v) {
                      w.faqItems[i].question = v;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 8),
                  _CmsTextField(
                    label: 'Answer',
                    value: w.faqItems[i].answer,
                    maxLines: 3,
                    onChanged: (v) {
                      w.faqItems[i].answer = v;
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
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
          _FaqEditor(onChanged: onChanged),
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
          Row(
            children: [
              Expanded(child: _sectionTitle('Top navigation tabs')),
              TextButton.icon(
                onPressed: () {
                  w.navItems.add(
                    CmsNavItem(
                      id: 'nav_${DateTime.now().microsecondsSinceEpoch}',
                      label: 'New tab',
                      targetType: CmsNavTargetType.builtin,
                      target: '/',
                    ),
                  );
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add tab'),
              ),
            ],
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: w.navItems.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = w.navItems.removeAt(oldIndex);
              w.navItems.insert(newIndex, item);
              onChanged();
            },
            itemBuilder: (context, index) {
              final item = w.navItems[index];
              return Card(
                key: ValueKey(item.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item.label,
                              decoration: const InputDecoration(
                                labelText: 'Label',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                item.label = v;
                                onChanged();
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              w.navItems.removeAt(index);
                              onChanged();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<CmsNavTargetType>(
                              value: item.targetType,
                              decoration: const InputDecoration(
                                labelText: 'Target type',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: CmsNavTargetType.builtin,
                                  child: Text('Built-in page'),
                                ),
                                DropdownMenuItem(
                                  value: CmsNavTargetType.customPage,
                                  child: Text('Custom page'),
                                ),
                                DropdownMenuItem(
                                  value: CmsNavTargetType.url,
                                  child: Text('URL'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                item.targetType = v;
                                onChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: item.target,
                              decoration: InputDecoration(
                                labelText:
                                    item.targetType == CmsNavTargetType.customPage
                                        ? 'Page slug'
                                        : item.targetType == CmsNavTargetType.url
                                        ? 'URL'
                                        : 'Route (e.g. /gallery)',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                item.target = v;
                                onChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Visible'),
                        value: item.visible,
                        onChanged: (v) {
                          item.visible = v;
                          w.touch();
                          onChanged();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CustomPagesEditor extends StatelessWidget {
  const _CustomPagesEditor({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return _cmsPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Custom pages')),
              TextButton.icon(
                onPressed: () {
                  final id = 'page_${DateTime.now().microsecondsSinceEpoch}';
                  w.customPages.add(
                    CmsCustomPage(
                      id: id,
                      slug: 'page-${w.customPages.length + 1}',
                      title: 'New page',
                    ),
                  );
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add page'),
              ),
            ],
          ),
          for (final page in w.customPages) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: page.title,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              page.title = v;
                              onChanged();
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            w.customPages.remove(page);
                            onChanged();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: page.slug,
                      decoration: const InputDecoration(
                        labelText: 'Slug (URL /p/slug)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        page.slug = v.trim().toLowerCase().replaceAll(' ', '-');
                        onChanged();
                      },
                    ),
                    const SizedBox(height: 12),
                    CmsSectionsEditor(
                      sections: page.sections,
                      onChanged: onChanged,
                      title: 'Page sections',
                    ),
                  ],
                ),
              ),
            ),
          ],
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
