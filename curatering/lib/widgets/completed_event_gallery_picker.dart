import 'package:flutter/material.dart';

import '../models/event_order.dart';
import '../services/events_api.dart';
import '../utils/image_cache.dart';
import '../utils/website_image_utils.dart';
import 'antd_buttons.dart';
import 'antd_dialog.dart';
import 'antd_tokens.dart';

class _CompletedEventImage {
  final String eventType;
  final String label;
  final String imageBase64;

  const _CompletedEventImage({
    required this.eventType,
    required this.label,
    required this.imageBase64,
  });
}

bool _looksLikeGalleryBase64(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('/')) {
    return false;
  }
  if (s.startsWith('data:image/')) return true;
  return s.length > 256 && !RegExp(r'\s').hasMatch(s.substring(0, s.length.clamp(0, 80)));
}

List<_CompletedEventImage> _imagesFromCompletedOrder(EventOrderDto order) {
  final type = order.eventType.trim().isEmpty ? 'Other' : order.eventType.trim();
  final title = order.eventTitle.trim().isEmpty ? order.transactionNo : order.eventTitle;
  final out = <_CompletedEventImage>[];
  final seen = <String>{};

  void add(String? raw, {String suffix = ''}) {
    final s = (raw ?? '').trim();
    if (!_looksLikeGalleryBase64(s)) return;
    final key = s.length > 120 ? s.substring(0, 120) : s;
    if (!seen.add(key)) return;
    out.add(
      _CompletedEventImage(
        eventType: type,
        label: suffix.isEmpty ? title : '$title · $suffix',
        imageBase64: s,
      ),
    );
  }

  add(order.themeDesign.generatedImageUrl, suffix: 'design');
  for (final p in order.themeDesign.picksBase64) {
    add(p, suffix: 'reference');
  }
  for (final img in order.actualEventImages) {
    add(img, suffix: 'photo');
  }
  return out;
}

/// Picks design/photo base64 images from completed catering/event orders,
/// grouped by event type tabs. Returns selected image payloads.
Future<List<String>?> showCompletedEventGalleryPicker(BuildContext context) {
  return showAntdModal<List<String>>(
    context: context,
    title: 'Add images',
    maxWidth: 860,
    body: const _CompletedEventGalleryPickerBody(),
    actions: const [],
  );
}

class _CompletedEventGalleryPickerBody extends StatefulWidget {
  const _CompletedEventGalleryPickerBody();

  @override
  State<_CompletedEventGalleryPickerBody> createState() =>
      _CompletedEventGalleryPickerBodyState();
}

class _CompletedEventGalleryPickerBodyState
    extends State<_CompletedEventGalleryPickerBody>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<_CompletedEventImage> _all = const [];
  final Set<int> _selected = {};
  TabController? _tabs;
  List<String> _types = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await EventsApi.instance.listOrders(
        status: 'completed',
        roleType: 'manager',
      );
      final images = <_CompletedEventImage>[];
      for (final o in orders) {
        images.addAll(_imagesFromCompletedOrder(o));
      }
      final types = images.map((e) => e.eventType).toSet().toList()..sort();
      _tabs?.dispose();
      _tabs = types.isEmpty ? null : TabController(length: types.length, vsync: this);
      if (!mounted) return;
      setState(() {
        _all = images;
        _types = types;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.58;
    if (_loading) {
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: height,
        child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }
    if (_all.isEmpty || _tabs == null) {
      return SizedBox(
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No completed event design images found.'),
            const SizedBox(height: 16),
            AntdPrimaryButton(
              label: 'Upload from device',
              onPressed: () async {
                final b64s = await pickMultipleWebsiteImagesBase64();
                if (b64s.isEmpty || !mounted) return;
                Navigator.of(context).pop(b64s);
              },
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select images from completed events, or upload from your device.',
            style: TextStyle(color: AntdTokens.labelMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AntdSecondaryButton(
              label: 'Upload from device instead',
              onPressed: () async {
                final b64s = await pickMultipleWebsiteImagesBase64();
                if (b64s.isEmpty || !mounted) return;
                Navigator.of(context).pop(b64s);
              },
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AntdTokens.valueDark,
            tabs: _types.map((t) => Tab(text: t)).toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _types.map((type) {
                final items = <MapEntry<int, _CompletedEventImage>>[];
                for (var i = 0; i < _all.length; i++) {
                  if (_all[i].eventType == type) {
                    items.add(MapEntry(i, _all[i]));
                  }
                }
                if (items.isEmpty) {
                  return const Center(child: Text('No images in this category.'));
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    final selected = _selected.contains(entry.key);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selected.remove(entry.key);
                          } else {
                            _selected.add(entry.key);
                          }
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedBase64Image(
                              base64String: entry.value.imageBase64,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (selected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFC024),
                                  width: 3,
                                ),
                              ),
                              child: const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFFFC024),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 6,
                            right: 6,
                            bottom: 6,
                            child: Text(
                              entry.value.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AntdCancelButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              AntdPrimaryButton(
                label: _selected.isEmpty
                    ? 'Add selected'
                    : 'Add ${_selected.length} selected',
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        final picked = _selected
                            .map((i) => _all[i].imageBase64)
                            .toList(growable: false);
                        Navigator.of(context).pop(picked);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
