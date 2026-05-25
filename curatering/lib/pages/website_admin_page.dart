import 'package:flutter/material.dart';

import '../config.dart';
import '../config/site_routes.dart';
import '../features/event_design/event_design_admin_screen.dart';
import '../services/website_content_store.dart';
import '../utils/gallery_search.dart';
import '../utils/website_image_utils.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_message.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/website_rich_text.dart';

/// Super-admin CMS for customer-facing homepage, gallery, and contact page content.
class WebsiteAdminPage extends StatefulWidget {
  const WebsiteAdminPage({super.key});

  @override
  State<WebsiteAdminPage> createState() => _WebsiteAdminPageState();
}

class _WebsiteAdminPageState extends State<WebsiteAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    WebsiteContentStore.instance.addListener(_onStore);
    WebsiteContentStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
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
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      await WebsiteContentStore.instance.save();
      await WebsiteContentStore.instance.reloadFromServer();
      if (!mounted) return;
      setState(() => _dirty = false);
      showAntdMessage(
        context,
        'Website content published. Refresh the customer site to see updates.',
        type: AntdMessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAntdMessage(context, 'Save failed: $e', type: AntdMessageType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = WebsiteContentStore.instance;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Website content',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Edit the public customer site — homepage, inquiry page, gallery, and contact us.',
                        style: TextStyle(color: AntdTokens.labelMuted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (isStaffSiteHost) {
                      redirectToSiteOrigin(customerSiteOrigin, '/');
                    } else {
                      Navigator.of(context).pushNamed(customerRoute('/'));
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Preview site'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/website'),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Live editor'),
                ),
                const SizedBox(width: 8),
                AntdPrimaryButton(
                  label: _dirty ? 'Save changes' : 'Saved',
                  loading: _saving,
                  onPressed: _saving ? null : _saveAll,
                ),
              ],
            ),
          ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                          'You have unsaved changes. Click Save changes to publish.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          TabBar(
            controller: _tabs,
            labelColor: const Color(0xFF1E1E1E),
            unselectedLabelColor: AntdTokens.labelMuted,
            indicatorColor: AntdTokens.brandPrimary,
            tabs: const [
              Tab(text: 'Homepage'),
              Tab(text: 'Restaurant page'),
              Tab(text: 'Inquiry page'),
              Tab(text: 'Gallery'),
              Tab(text: 'Contact us'),
            ],
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                return TabBarView(
                  controller: _tabs,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _HomepageEditorTab(onChanged: _markDirty),
                    _RestaurantEditorTab(onChanged: _markDirty),
                    _InquiryEditorTab(onChanged: _markDirty),
                    _GalleryEditorTab(onChanged: _markDirty),
                    _ContactEditorTab(onChanged: _markDirty),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantEditorTab extends StatelessWidget {
  const _RestaurantEditorTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Restaurant page text'),
              _textField(
                label: 'Page title',
                value: w.restaurantPageTitle,
                onChanged: (v) {
                  w.restaurantPageTitle = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Subtitle',
                value: w.restaurantPageSubtitle,
                onChanged: (v) {
                  w.restaurantPageSubtitle = v;
                  onChanged();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InquiryEditorTab extends StatelessWidget {
  const _InquiryEditorTab({required this.onChanged});

  final VoidCallback onChanged;

  Future<void> _openEventDesignOptions(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 760,
              height: 680,
              child: EventDesignAdminScreen(apiBase: apiBaseUrl),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Inquiry page text'),
              _textField(
                label: 'Page title',
                value: w.inquiryPageTitle,
                onChanged: (v) {
                  w.inquiryPageTitle = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Subtitle badge',
                value: w.inquiryPageSubtitle,
                onChanged: (v) {
                  w.inquiryPageSubtitle = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 24),
              _sectionTitle('Inquiry page event design'),
              const Text(
                'Manage the style, mood, color, and decor choices shown in the customer inquiry event design flow.',
                style: TextStyle(color: AntdTokens.labelMuted, height: 1.35),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _openEventDesignOptions(context),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Edit event design options'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomepageEditorTab extends StatelessWidget {
  const _HomepageEditorTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Hero image'),
              _imageField(
                b64: w.homeHeroImageBase64,
                height: 200,
                onPick: () async {
                  final b64 = await pickWebsiteImageBase64();
                  if (b64 == null) return;
                  w.homeHeroImageBase64 = b64;
                  onChanged();
                  w.touch();
                },
                onClear: () {
                  w.homeHeroImageBase64 = '';
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 24),
              _sectionTitle('Red banner text'),
              _richTextField(
                context: context,
                label: 'Banner',
                value: w.redBannerText,
                onChanged: (v) {
                  w.redBannerText = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 24),
              _sectionTitle('Latest event block'),
              _textField(
                label: 'Section label',
                value: w.latestEventSectionLabel,
                onChanged: (v) {
                  w.latestEventSectionLabel = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Title',
                value: w.latestEventTitle,
                onChanged: (v) {
                  w.latestEventTitle = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Subtitle',
                value: w.latestEventSubtitle,
                onChanged: (v) {
                  w.latestEventSubtitle = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Body',
                value: w.latestEventBody,
                onChanged: (v) {
                  w.latestEventBody = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 16),
              _multiImageList(
                title: 'Event collage images',
                images: w.latestEventCollageBase64,
                onAdd: () async {
                  final imgs = await pickMultipleWebsiteImagesBase64();
                  if (imgs.isEmpty) return;
                  w.latestEventCollageBase64.addAll(imgs);
                  onChanged();
                  w.touch();
                },
                onRemove: (i) {
                  w.latestEventCollageBase64.removeAt(i);
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 24),
              _sectionTitle('Popular dishes text'),
              _textField(
                label: 'Section label',
                value: w.popularDishesSectionLabel,
                onChanged: (v) {
                  w.popularDishesSectionLabel = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Subtitle',
                value: w.popularDishesSubtitle,
                onChanged: (v) {
                  w.popularDishesSubtitle = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 16),
              _multiImageList(
                title: 'Popular dishes carousel',
                images: w.popularDishImageBase64,
                onAdd: () async {
                  final imgs = await pickMultipleWebsiteImagesBase64();
                  if (imgs.isEmpty) return;
                  w.popularDishImageBase64.addAll(imgs);
                  for (var i = 0; i < imgs.length; i++) {
                    w.popularDishLabels.add(
                      'Dish ${w.popularDishLabels.length + 1}',
                    );
                  }
                  onChanged();
                  w.touch();
                },
                onRemove: (i) {
                  w.popularDishImageBase64.removeAt(i);
                  if (i < w.popularDishLabels.length) {
                    w.popularDishLabels.removeAt(i);
                  }
                  onChanged();
                  w.touch();
                },
              ),
              if (w.popularDishImageBase64.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...List.generate(w.popularDishImageBase64.length, (i) {
                  final label =
                      i < w.popularDishLabels.length
                          ? w.popularDishLabels[i]
                          : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _textField(
                      label: 'Label for image ${i + 1}',
                      value: label,
                      onChanged: (v) {
                        while (w.popularDishLabels.length <= i) {
                          w.popularDishLabels.add('');
                        }
                        w.popularDishLabels[i] = v;
                        onChanged();
                        w.touch();
                      },
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              _sectionTitle('Event designs text'),
              _textField(
                label: 'Section label',
                value: w.eventDesignsSectionLabel,
                onChanged: (v) {
                  w.eventDesignsSectionLabel = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Subtitle',
                value: w.eventDesignsSubtitle,
                onChanged: (v) {
                  w.eventDesignsSubtitle = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 16),
              _multiImageList(
                title: 'Event design showcase',
                images: w.eventDesignImageBase64,
                onAdd: () async {
                  final imgs = await pickMultipleWebsiteImagesBase64();
                  if (imgs.isEmpty) return;
                  w.eventDesignImageBase64.addAll(imgs);
                  onChanged();
                  w.touch();
                },
                onRemove: (i) {
                  w.eventDesignImageBase64.removeAt(i);
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 24),
              _sectionTitle('Footer'),
              _textField(
                label: 'Privacy policy label',
                value: w.footerPrivacyLabel,
                onChanged: (v) {
                  w.footerPrivacyLabel = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Copyright line',
                value: w.footerCopyright,
                onChanged: (v) {
                  w.footerCopyright = v;
                  onChanged();
                  w.touch();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryEditorTab extends StatelessWidget {
  const _GalleryEditorTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Gallery page text'),
              _richTextField(
                context: context,
                label: 'Gallery title',
                value: w.galleryTitle,
                onChanged: (v) {
                  w.galleryTitle = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Gallery intro',
                value: w.galleryIntro,
                onChanged: (v) {
                  w.galleryIntro = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Gallery categories appear on the public Gallery page.',
                      style: TextStyle(color: AntdTokens.labelMuted),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final id = 'c${DateTime.now().millisecondsSinceEpoch}';
                      w.galleryCategories.add(
                        GalleryCategoryData(id: id, label: 'NEW CATEGORY'),
                      );
                      onChanged();
                      w.touch();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add category'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...w.galleryCategories.asMap().entries.map((entry) {
                final i = entry.key;
                final cat = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    initiallyExpanded: i == 0,
                    title: Text(cat.label.isEmpty ? 'Untitled' : cat.label),
                    subtitle: Text('${cat.images.length} photos'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _textField(
                              label: 'Category name',
                              value: cat.label,
                              onChanged: (v) {
                                cat.label = v;
                                onChanged();
                                w.touch();
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: InputDecoration(
                                labelText: 'Default tags for new photos',
                                hintText: galleryTagsHint(),
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged:
                                  (v) =>
                                      cat.defaultTagsForUpload = parseTagsInput(
                                        v,
                                      ),
                            ),
                            const SizedBox(height: 12),
                            ...cat.images.asMap().entries.map((imgEntry) {
                              final j = imgEntry.key;
                              final img = imgEntry.value;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 88,
                                          child: websiteBase64Thumbnail(
                                            img.imageBase64,
                                            height: 88,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (img.tags.isNotEmpty)
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children:
                                                    img.tags
                                                        .map(
                                                          (t) => Chip(
                                                            label: Text(
                                                              t,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                          ),
                                                        )
                                                        .toList(),
                                              )
                                            else
                                              Text(
                                                'No tags',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            TextButton.icon(
                                              onPressed: () async {
                                                final ctrl =
                                                    TextEditingController(
                                                      text: img.tags.join(', '),
                                                    );
                                                final saved = await showDialog<
                                                  bool
                                                >(
                                                  context: context,
                                                  builder:
                                                      (ctx) => AlertDialog(
                                                        title: const Text(
                                                          'Photo tags',
                                                        ),
                                                        content: TextField(
                                                          controller: ctrl,
                                                          decoration:
                                                              InputDecoration(
                                                                hintText:
                                                                    galleryTagsHint(),
                                                              ),
                                                          maxLines: 2,
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      false,
                                                                    ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          FilledButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      true,
                                                                    ),
                                                            child: const Text(
                                                              'Save',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                                if (saved == true) {
                                                  img.tags
                                                    ..clear()
                                                    ..addAll(
                                                      parseTagsInput(ctrl.text),
                                                    );
                                                  onChanged();
                                                  w.touch();
                                                }
                                                ctrl.dispose();
                                              },
                                              icon: const Icon(
                                                Icons.label_outline,
                                                size: 18,
                                              ),
                                              label: const Text('Edit tags'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove photo',
                                        onPressed: () {
                                          cat.images.removeAt(j);
                                          onChanged();
                                          w.touch();
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final imgs =
                                        await pickMultipleWebsiteImagesBase64();
                                    if (imgs.isEmpty) return;
                                    cat.addImagesFromBase64(
                                      imgs,
                                      defaultTags: cat.defaultTagsForUpload,
                                    );
                                    onChanged();
                                    w.touch();
                                  },
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Add photos'),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    w.galleryCategories.removeAt(i);
                                    onChanged();
                                    w.touch();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AntdTokens.error,
                                  ),
                                  child: const Text('Delete category'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactEditorTab extends StatelessWidget {
  const _ContactEditorTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final w = WebsiteContentStore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'These fields appear on the public Contact Us page and footer.',
                style: TextStyle(color: AntdTokens.labelMuted),
              ),
              const SizedBox(height: 20),
              _richTextField(
                context: context,
                label: 'Contact page title',
                value: w.contactTitle,
                onChanged: (v) {
                  w.contactTitle = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Contact banner',
                value: w.contactBannerText,
                onChanged: (v) {
                  w.contactBannerText = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Contact reach-us label',
                value: w.contactReachUsLabel,
                onChanged: (v) {
                  w.contactReachUsLabel = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _richTextField(
                context: context,
                label: 'Contact page intro',
                value: w.contactPageIntro,
                onChanged: (v) {
                  w.contactPageIntro = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Facebook / social label',
                value: w.contactFacebook,
                onChanged: (v) {
                  w.contactFacebook = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Address',
                value: w.contactAddress,
                maxLines: 3,
                onChanged: (v) {
                  w.contactAddress = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Business hours',
                value: w.contactHours,
                onChanged: (v) {
                  w.contactHours = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Phone',
                value: w.contactPhone,
                onChanged: (v) {
                  w.contactPhone = v;
                  onChanged();
                  w.touch();
                },
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Email',
                value: w.contactEmail,
                onChanged: (v) {
                  w.contactEmail = v;
                  onChanged();
                  w.touch();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}

Widget _textField({
  required String label,
  required String value,
  required ValueChanged<String> onChanged,
  int maxLines = 1,
}) {
  return TextFormField(
    initialValue: value,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.grey.shade50,
    ),
    onChanged: onChanged,
  );
}

Widget _richTextField({
  required BuildContext context,
  required String label,
  required String value,
  required ValueChanged<String> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AntdTokens.labelMuted,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: WebsiteRichText(
          value: value.isEmpty ? '(empty)' : value,
          style: const TextStyle(fontSize: 14, height: 1.35),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          final edited = await showWebsiteRichTextEditor(
            context: context,
            title: 'Edit $label',
            initialValue: value,
          );
          if (edited != null) onChanged(edited);
        },
        icon: const Icon(Icons.format_paint_outlined, size: 18),
        label: const Text('Edit formatting'),
      ),
    ],
  );
}

Widget _imageField({
  required String b64,
  required double height,
  required VoidCallback onPick,
  required VoidCallback onClear,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: websiteBase64Thumbnail(b64, height: height),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload),
            label: const Text('Upload image'),
          ),
          const SizedBox(width: 8),
          if (b64.isNotEmpty)
            TextButton(onPressed: onClear, child: const Text('Remove')),
        ],
      ),
    ],
  );
}

Widget _multiImageList({
  required String title,
  required List<String> images,
  required VoidCallback onAdd,
  required void Function(int index) onRemove,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add images'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (images.isEmpty)
        Text('No images yet.', style: TextStyle(color: Colors.grey.shade600))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < images.length; i++)
              SizedBox(
                width: 120,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: websiteBase64Thumbnail(images[i], height: 90),
                    ),
                    TextButton(
                      onPressed: () => onRemove(i),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
          ],
        ),
    ],
  );
}
