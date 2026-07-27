import 'package:flutter/material.dart';

import '../services/website_content_store.dart';
import '../utils/website_image_utils.dart';
import 'antd_buttons.dart';
import 'antd_dialog.dart';
import 'antd_message.dart';
import 'antd_tokens.dart';

/// Pick an existing media asset or upload a new one.
Future<WebsiteMediaItem?> showWebsiteMediaPicker(BuildContext context) {
  return showAntdModal<WebsiteMediaItem>(
    context: context,
    title: 'Media library',
    maxWidth: 720,
    body: const _WebsiteMediaPickerBody(),
    actions: [
      AntdCancelButton(
        label: 'Cancel',
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}

class _WebsiteMediaPickerBody extends StatefulWidget {
  const _WebsiteMediaPickerBody();

  @override
  State<_WebsiteMediaPickerBody> createState() =>
      _WebsiteMediaPickerBodyState();
}

class _WebsiteMediaPickerBodyState extends State<_WebsiteMediaPickerBody> {
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
      final items =
          await WebsiteContentStore.instance.listMedia(query: _query);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Failed to load media: $e',
          type: AntdMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final b64 = await pickWebsiteImageBase64();
    if (b64 == null) return;
    try {
      final item = await WebsiteContentStore.instance.uploadMedia(
        dataBase64: b64,
        name: 'upload-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      Navigator.pop(context, item);
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Upload failed: $e',
          type: AntdMessageType.error,
        );
      }
    }
  }

  Future<void> _select(WebsiteMediaItem item) async {
    if (item.dataBase64 == null || item.dataBase64!.isEmpty) {
      final b64 =
          await WebsiteContentStore.instance.resolveMediaId(item.id);
      item = WebsiteMediaItem(
        id: item.id,
        name: item.name,
        mime: item.mime,
        byteSize: item.byteSize,
        tags: item.tags,
        createdAt: item.createdAt,
        dataBase64: b64,
      );
    }
    if (!mounted) return;
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onChanged: (v) => _query = v,
                  onSubmitted: (_) => _reload(),
                ),
              ),
              const SizedBox(width: 8),
              AntdSecondaryButton(label: 'Search', onPressed: _reload),
              const SizedBox(width: 8),
              AntdPrimaryButton(label: 'Upload new', onPressed: _upload),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(
                  child: Text(
                    'No media yet. Upload an image.',
                    style: TextStyle(color: AntdTokens.labelMuted),
                  ),
                )
                : GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final m = _items[i];
                    return InkWell(
                      onTap: () => _select(m),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: FutureBuilder<String?>(
                                future: WebsiteContentStore.instance
                                    .resolveMediaId(m.id),
                                builder: (context, snap) {
                                  return websiteBase64Thumbnail(
                                    snap.data,
                                    height: 80,
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
