import 'package:flutter/material.dart';

import '../services/mobile_ui_cms.dart';
import '../services/website_content_store.dart';
import 'website_media_picker.dart';

/// Super-admin editor for customer mobile app layouts.
class MobileUiCmsEditor extends StatefulWidget {
  const MobileUiCmsEditor({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<MobileUiCmsEditor> createState() => _MobileUiCmsEditorState();
}

class _MobileUiCmsEditorState extends State<MobileUiCmsEditor> {
  String _screenId = kMobileUiScreenIds.first;
  String? _selectedBlockId;

  MobileUiConfig get _cfg => WebsiteContentStore.instance.mobileUi;

  MobileUiScreen get _screen => _cfg.screen(_screenId);

  void _touch() {
    widget.onChanged();
    setState(() {});
  }

  Future<void> _addBlock() async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add block'),
        children: [
          for (final t in kMobileUiBlockTypes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Text(_blockTypeLabel(t)),
            ),
        ],
      ),
    );
    if (type == null) return;
    final block = MobileUiBlock.create(type);
    _screen.blocks.add(block);
    _selectedBlockId = block.id;
    _touch();
  }

  void _resetScreenDefaults() {
    final defaults = defaultMobileUiConfig().screen(_screenId);
    _cfg.screens[_screenId] = MobileUiScreen(
      id: _screenId,
      blocks: defaults.blocks.map((b) => MobileUiBlock.fromJson(b.toJson())).toList(),
    );
    _selectedBlockId = null;
    _touch();
  }

  void _resetAllDefaults() {
    WebsiteContentStore.instance.mobileUi = defaultMobileUiConfig();
    _selectedBlockId = null;
    _touch();
  }

  MobileUiBlock? get _selected {
    final id = _selectedBlockId;
    if (id == null) return null;
    for (final b in _screen.blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final editor = _buildEditorColumn(selected);
        final preview = _PhonePreview(screen: _screen, brand: _cfg.brand);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: editor),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: preview),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            editor,
            const SizedBox(height: 16),
            Center(child: preview),
          ],
        );
      },
    );
  }

  Widget _buildEditorColumn(MobileUiBlock? selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mobile App layouts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Edit customer app screens. Publish to push layouts to the mobile apps. '
          'Transactional forms (login, checkout, payment) keep native fields; banners/slots are CMS-driven.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 16),
        _brandCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _screenId,
                decoration: const InputDecoration(
                  labelText: 'Screen',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final id in kMobileUiScreenIds)
                    DropdownMenuItem(
                      value: id,
                      child: Text(kMobileUiScreenLabels[id] ?? id),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _screenId = v;
                    _selectedBlockId = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _resetScreenDefaults,
              child: const Text('Reset screen'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _resetAllDefaults,
              child: const Text('Reset all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Blocks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _addBlock,
              icon: const Icon(Icons.add),
              label: const Text('Add block'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_screen.blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No blocks — mobile will use hardcoded fallback for this screen until you add blocks and publish.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _screen.blocks.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _screen.blocks.removeAt(oldIndex);
              _screen.blocks.insert(newIndex, item);
              _touch();
            },
            itemBuilder: (context, index) {
              final b = _screen.blocks[index];
              final selectedNow = b.id == _selectedBlockId;
              return Card(
                key: ValueKey(b.id),
                color: selectedNow ? Colors.amber.shade50 : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle),
                  title: Text('${_blockTypeLabel(b.type)} · ${b.title.isEmpty ? b.slot.isEmpty ? b.id : b.slot : b.title}'),
                  subtitle: Text(b.body.isEmpty ? b.route : b.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  selected: selectedNow,
                  onTap: () => setState(() => _selectedBlockId = b.id),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      _screen.blocks.removeAt(index);
                      if (_selectedBlockId == b.id) _selectedBlockId = null;
                      _touch();
                    },
                  ),
                ),
              );
            },
          ),
        if (selected != null) ...[
          const SizedBox(height: 16),
          _BlockPropsEditor(block: selected, onChanged: _touch),
        ],
      ],
    );
  }

  Widget _brandCard() {
    final brand = _cfg.brand;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Brand (mobile)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: brand.primary,
                    decoration: const InputDecoration(
                      labelText: 'Primary color',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      brand.primary = v.trim();
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: brand.accent,
                    decoration: const InputDecoration(
                      labelText: 'Accent color',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      brand.accent = v.trim();
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    brand.logoMediaId?.isNotEmpty == true
                        ? 'Logo media: ${brand.logoMediaId}'
                        : 'No logo media selected',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final mid = await pickWebsiteMediaId(context);
                    if (mid == null) return;
                    brand.logoMediaId = mid;
                    _touch();
                  },
                  child: const Text('Pick logo'),
                ),
                if (brand.logoMediaId?.isNotEmpty == true)
                  TextButton(
                    onPressed: () {
                      brand.logoMediaId = null;
                      _touch();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockPropsEditor extends StatelessWidget {
  const _BlockPropsEditor({required this.block, required this.onChanged});

  final MobileUiBlock block;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit · ${_blockTypeLabel(block.type)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (block.type != 'spacer' && block.type != 'divider' && block.type != 'native_slot')
              TextFormField(
                initialValue: block.title,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                onChanged: (v) {
                  block.title = v;
                  onChanged();
                },
              ),
            if (block.type == 'hero' ||
                block.type == 'banner_notice' ||
                block.type == 'rich_text' ||
                block.type == 'heading') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: block.body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()),
                onChanged: (v) {
                  block.body = v;
                  onChanged();
                },
              ),
            ],
            if (block.type == 'cta') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: block.ctaLabel,
                decoration: const InputDecoration(labelText: 'Button label', border: OutlineInputBorder()),
                onChanged: (v) {
                  block.ctaLabel = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: kMobileUiRoutes.contains(block.route) ? block.route : 'menu',
                decoration: const InputDecoration(labelText: 'Route', border: OutlineInputBorder()),
                items: [
                  for (final r in kMobileUiRoutes) DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  block.route = v;
                  onChanged();
                },
              ),
              if (block.route == 'url') ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: block.url,
                  decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder()),
                  onChanged: (v) {
                    block.url = v;
                    onChanged();
                  },
                ),
              ],
            ],
            if (block.type == 'image' || block.type == 'hero') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      block.mediaId?.isNotEmpty == true ? 'Media: ${block.mediaId}' : 'No image',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final mid = await pickWebsiteMediaId(context);
                      if (mid == null) return;
                      block.mediaId = mid;
                      onChanged();
                    },
                    child: const Text('Pick image'),
                  ),
                ],
              ),
            ],
            if (block.type == 'native_slot') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: block.slot,
                decoration: const InputDecoration(
                  labelText: 'Slot id (e.g. menu_body, inquire_wizard)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  block.slot = v.trim();
                  onChanged();
                },
              ),
            ],
            if (block.type == 'spacer') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: block.height.toStringAsFixed(0),
                decoration: const InputDecoration(labelText: 'Height (px)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  block.height = double.tryParse(v) ?? 16;
                  onChanged();
                },
              ),
            ],
            if (block.type == 'tile_grid' || block.type == 'nav_tabs') ...[
              const SizedBox(height: 12),
              const Text('Tiles', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (var i = 0; i < block.tiles.length; i++) ...[
                _TileEditor(
                  tile: block.tiles[i],
                  onChanged: onChanged,
                  onRemove: () {
                    block.tiles.removeAt(i);
                    onChanged();
                  },
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    block.tiles.add(
                      MobileUiTile(
                        id: 'tile_${DateTime.now().microsecondsSinceEpoch}',
                        title: 'New tile',
                        route: 'menu',
                      ),
                    );
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add tile'),
                ),
              ),
            ],
            if (block.type == 'package_cards') ...[
              const SizedBox(height: 12),
              const Text('Packages', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (var i = 0; i < block.packages.length; i++) ...[
                _PackageEditor(
                  card: block.packages[i],
                  onChanged: onChanged,
                  onRemove: () {
                    block.packages.removeAt(i);
                    onChanged();
                  },
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    block.packages.add(
                      MobileUiPackageCard(
                        id: 'pkg_${DateTime.now().microsecondsSinceEpoch}',
                        title: 'New package',
                        lines: const ['Detail line'],
                      ),
                    );
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add package'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TileEditor extends StatelessWidget {
  const _TileEditor({required this.tile, required this.onChanged, required this.onRemove});
  final MobileUiTile tile;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: tile.title,
                  decoration: const InputDecoration(labelText: 'Title', isDense: true),
                  onChanged: (v) {
                    tile.title = v;
                    onChanged();
                  },
                ),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
            ],
          ),
          TextFormField(
            initialValue: tile.subtitle,
            decoration: const InputDecoration(labelText: 'Subtitle', isDense: true),
            onChanged: (v) {
              tile.subtitle = v;
              onChanged();
            },
          ),
          DropdownButtonFormField<String>(
            value: kMobileUiRoutes.contains(tile.route) ? tile.route : 'menu',
            decoration: const InputDecoration(labelText: 'Route', isDense: true),
            items: [
              for (final r in kMobileUiRoutes) DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) {
              if (v == null) return;
              tile.route = v;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _PackageEditor extends StatelessWidget {
  const _PackageEditor({required this.card, required this.onChanged, required this.onRemove});
  final MobileUiPackageCard card;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: card.title,
                  decoration: const InputDecoration(labelText: 'Package title', isDense: true),
                  onChanged: (v) {
                    card.title = v;
                    onChanged();
                  },
                ),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
            ],
          ),
          TextFormField(
            initialValue: card.lines.join('\n'),
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Lines (one per line)',
              isDense: true,
            ),
            onChanged: (v) {
              card.lines = v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.screen, required this.brand});

  final MobileUiScreen screen;
  final MobileUiBrand brand;

  Color _parse(String hex, Color fallback) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final primary = _parse(brand.primary, const Color(0xFFFFC233));
    return Column(
      children: [
        Text('Phone preview', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          width: 300,
          height: 560,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.grey.shade700, width: 3),
          ),
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F4F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final b in screen.blocks) _previewBlock(b, primary),
                if (screen.blocks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Empty — hardcoded UI on device', textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewBlock(MobileUiBlock b, Color primary) {
    switch (b.type) {
      case 'hero':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: primary)),
              if (b.body.isNotEmpty) Text(b.body, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      case 'banner_notice':
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          color: const Color(0xFFFFF3CD),
          child: Text(b.body, style: const TextStyle(fontSize: 12)),
        );
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        );
      case 'cta':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            color: primary,
            child: Text(b.ctaLabel.isEmpty ? 'Button' : b.ctaLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      case 'tile_grid':
      case 'nav_tabs':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in b.tiles)
                Container(
                  width: b.type == 'nav_tabs' ? 60 : 120,
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: Text(t.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        );
      case 'package_cards':
        return Column(
          children: [
            for (final p in b.packages)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    for (final line in p.lines) Text(line, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
          ],
        );
      case 'native_slot':
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueGrey.shade200, style: BorderStyle.solid),
            color: Colors.blueGrey.shade50,
          ),
          child: Text('Native slot: ${b.slot.isEmpty ? "body" : b.slot}', textAlign: TextAlign.center),
        );
      case 'spacer':
        return SizedBox(height: b.height.clamp(4, 64));
      case 'divider':
        return const Divider();
      case 'image':
        return Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: Text(b.mediaId?.isNotEmpty == true ? 'Image' : 'No image'),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('${b.type}: ${b.title}'),
        );
    }
  }
}

String _blockTypeLabel(String type) => switch (type) {
      'hero' => 'Hero',
      'banner_notice' => 'Banner notice',
      'heading' => 'Heading',
      'rich_text' => 'Rich text',
      'image' => 'Image',
      'cta' => 'Call to action',
      'tile_grid' => 'Tile grid',
      'nav_tabs' => 'Nav tabs',
      'package_cards' => 'Package cards',
      'spacer' => 'Spacer',
      'divider' => 'Divider',
      'native_slot' => 'Native slot',
      _ => type,
    };

Future<String?> pickWebsiteMediaId(BuildContext context) async {
  final picked = await showWebsiteMediaPicker(context);
  return picked?.id;
}
