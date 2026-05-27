import 'dart:convert';

import 'package:flutter/material.dart';

import '../../utils/image_pick_limits.dart';
import 'event_design_categories.dart';
import 'events_feature_api.dart';
import 'runpod_service.dart';
import 'theme_design_export.dart';

enum _ThemeDesignTab { styleMood, colorsDecor, venuePhotos, generate }

class EventThemeDesignScreen extends StatefulWidget {
  const EventThemeDesignScreen({
    super.key,
    required this.apiBase,
    required this.userEmail,
    this.orderId,
    this.orderKind = 'event',
    this.designSessionId,
    required this.initialEventType,
    this.initialThemeDesign,
    this.eventTitle,
    this.formalityLevel,
    this.eventSetting,
    this.cashierEmail,
    this.cashierPassword,
    this.persistToOrder = false,
    this.embedded = false,
  });

  final String apiBase;
  final String userEmail;
  final String? orderId;
  final String orderKind;
  final String? designSessionId;
  final String initialEventType;
  final Map<String, dynamic>? initialThemeDesign;
  final String? eventTitle;
  final String? formalityLevel;
  final String? eventSetting;
  final String? cashierEmail;
  final String? cashierPassword;
  final bool persistToOrder;
  final bool embedded;

  @override
  State<EventThemeDesignScreen> createState() => _EventThemeDesignScreenState();
}

class _EventThemeDesignScreenState extends State<EventThemeDesignScreen> {
  static const _accentYellow = Color(0xFFE8B923);
  static const _darkHeader = Color(0xFF242424);

  late final String _eventType;
  _ThemeDesignTab _activeTab = _ThemeDesignTab.styleMood;
  EventDesignCategories _categories = EventDesignCategories.defaults;
  String? _style;
  String? _mood;
  final Set<String> _palettes = {};
  final Set<String> _decor = {};
  final TextEditingController _notes = TextEditingController();
  final List<String> _venuePhotosB64 = [];
  final List<String> _previousUrls = [];
  String? _generatedUrl;
  String? _generateError;
  bool _generating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _eventType =
        widget.initialEventType.trim().isEmpty
            ? 'Birthday'
            : widget.initialEventType.trim();
    final theme = widget.initialThemeDesign ?? const <String, dynamic>{};
    _style = _clean(theme['style']);
    _mood = _clean(theme['mood']);
    _notes.text = _clean(theme['customInstructions'] ?? theme['note']) ?? '';
    for (final value in _asList(theme['colorPalette'] ?? theme['colors'])) {
      _palettes.add(value);
    }
    for (final value in _asList(theme['decorElements'] ?? theme['decor'])) {
      _decor.add(value);
    }
    for (final value in _asList(
      theme['venuePhotos'] ?? theme['reference_images'],
    )) {
      _venuePhotosB64.add(value);
    }
    final singleVenue = _clean(theme['venuePhotoBase64']);
    if (singleVenue != null && !_venuePhotosB64.contains(singleVenue)) {
      _venuePhotosB64.add(singleVenue);
    }
    _generatedUrl = _clean(theme['generatedImageUrl'] ?? theme['imageUrl']);
    for (final value in _asList(theme['previousGeneratedImageUrls'])) {
      if (value != _generatedUrl) _previousUrls.add(value);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String? _clean(dynamic value) {
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  List<String> _asList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty && e != 'null')
        .toList();
  }

  Future<void> _loadCategories() async {
    try {
      final loaded =
          await EventsFeatureApi(
            apiBase: widget.apiBase,
          ).getEventDesignCategories();
      if (mounted) setState(() => _categories = loaded);
    } catch (_) {}
  }

  Future<void> _pickVenuePhotos() async {
    final picked = await pickImagesBase64(
      context: context,
      allowMultiple: true,
      maxWidth: 1600,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      for (final image in picked) {
        if (!_venuePhotosB64.contains(image)) _venuePhotosB64.add(image);
      }
    });
  }

  String _prompt() {
    return [
      '$_eventType event venue',
      if (_style != null) '$_style theme',
      if (_mood != null) '$_mood atmosphere',
      if (_palettes.isNotEmpty) '${_palettes.join(', ')} color palette',
      if (_decor.isNotEmpty) '${_decor.join(', ')} decorations',
      if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
      'photorealistic',
      'luxury interior photography',
      'realistic event styling',
      'cinematic lighting',
    ].join(', ');
  }

  Map<String, dynamic> _eventConfig() {
    return {
      'task_type': 'event_prompt_expansion',
      'event_type': _eventType,
      if (_style != null) ...{'theme': _style, 'style': _style},
      if (_mood != null) 'mood': _mood,
      'colors': _palettes.toList(),
      'color_palette': _palettes.toList(),
      'decor': _decor.toList(),
      'decor_elements': _decor.toList(),
      if (_notes.text.trim().isNotEmpty) ...{
        'notes': _notes.text.trim(),
        'custom_instructions': _notes.text.trim(),
      },
      if (widget.formalityLevel?.trim().isNotEmpty == true)
        'formality': widget.formalityLevel!.trim(),
      if (widget.eventSetting?.trim().isNotEmpty == true)
        'event_setting': widget.eventSetting!.trim(),
    };
  }

  Map<String, dynamic> _runpodMeta(EventPromptExpansion expansion) {
    return {
      ..._eventConfig(),
      'task_type': 'sdxl_event_design',
      'use_nlp_prompt_expansion': false,
      ...expansion.toSdxlMeta(),
      'negative_prompt':
          expansion.negativePrompt.isNotEmpty
              ? expansion.negativePrompt
              : 'warped architecture, distorted room, melted surfaces, duplicate objects, blurry, low quality, cartoon, CGI, fisheye',
      'controlnet': {
        'enabled': true,
        'preprocessor': 'canny',
        'preserve_venue': true,
        'conditioning_scale': 0.65,
      },
      'controlnet_conditioning_scale': 0.65,
    };
  }

  Map<String, dynamic> _themeDesign() {
    return {
      'eventDesignSource': 'customer_ai',
      'wantsCustomDesign': true,
      'eventType': _eventType,
      if (_style != null) 'style': _style,
      if (_mood != null) 'mood': _mood,
      'colorPalette': _palettes.toList(),
      'decorElements': _decor.toList(),
      'customInstructions': _notes.text.trim(),
      'venuePhotos': _venuePhotosB64,
      if (_venuePhotosB64.isNotEmpty) 'venuePhotoBase64': _venuePhotosB64.first,
      if (_generatedUrl != null) 'generatedImageUrl': _generatedUrl,
      'previousGeneratedImageUrls': [
        if (_generatedUrl != null) _generatedUrl,
        ..._previousUrls,
      ],
    };
  }

  Future<void> _generate() async {
    if (_venuePhotosB64.isEmpty) {
      setState(
        () => _generateError = 'Upload a venue photo before generating.',
      );
      return;
    }
    setState(() {
      _generating = true;
      _generateError = null;
    });
    try {
      final fallbackPrompt = _prompt();
      final expansion = await RunPodService.expandEventPrompt(
        _eventConfig(),
        fallbackPrompt: fallbackPrompt,
      );
      final url = await RunPodService.generateImageWithPolling(
        expansion.positivePrompt,
        user_id: widget.userEmail,
        initImageBase64: _venuePhotosB64.first,
        strength: expansion.recommendedStrength ?? 0.58,
        numInferenceSteps: 30,
        guidanceScale: 6.5,
        designMeta: _runpodMeta(expansion),
      );
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        throw Exception('No generated image URL returned.');
      }
      setState(() {
        if (_generatedUrl != null && !_previousUrls.contains(_generatedUrl)) {
          _previousUrls.insert(0, _generatedUrl!);
        }
        _generatedUrl = url;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generateError = '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    final theme = _themeDesign();
    if (widget.persistToOrder && (widget.orderId ?? '').trim().isNotEmpty) {
      setState(() => _saving = true);
      try {
        await EventsFeatureApi(apiBase: widget.apiBase).saveThemeDesign(
          orderId: widget.orderId!,
          orderKind: widget.orderKind,
          themeDesign: theme,
          userEmail: widget.userEmail,
          cashierEmail: widget.cashierEmail,
          cashierPassword: widget.cashierPassword,
        );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    if (mounted) Navigator.pop(context, theme);
  }

  Widget _choiceChips(
    String title,
    List<String> options,
    Set<String> selected,
    ValueChanged<String> onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: (_) => onToggle(option),
              ),
          ],
        ),
      ],
    );
  }

  Widget _singleChoice(
    String title,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value != null && options.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }

  String _tabLabel(_ThemeDesignTab tab) {
    switch (tab) {
      case _ThemeDesignTab.styleMood:
        return 'Set Style and Mood';
      case _ThemeDesignTab.colorsDecor:
        return 'Choose Colors and Decor';
      case _ThemeDesignTab.venuePhotos:
        return 'Upload Venue Reference Photos';
      case _ThemeDesignTab.generate:
        return 'Generate Theme Design';
    }
  }

  IconData _tabIcon(_ThemeDesignTab tab) {
    switch (tab) {
      case _ThemeDesignTab.styleMood:
        return Icons.style_outlined;
      case _ThemeDesignTab.colorsDecor:
        return Icons.palette_outlined;
      case _ThemeDesignTab.venuePhotos:
        return Icons.photo_library_outlined;
      case _ThemeDesignTab.generate:
        return Icons.auto_awesome;
    }
  }

  Widget _buildSideTabNav() {
    const tabs = _ThemeDesignTab.values;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              'Event type: $_eventType',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Divider(height: 1),
          ...tabs.map((tab) {
            final active = _activeTab == tab;
            return Material(
              color: active ? _accentYellow.withValues(alpha: 0.18) : Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _activeTab = tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: active ? _accentYellow : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _tabIcon(tab),
                        size: 18,
                        color: active ? _darkHeader : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _tabLabel(tab),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                            color: active ? _darkHeader : Colors.grey.shade700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStyleMoodPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set Style and Mood',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the overall look and atmosphere for this event.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 16),
        _singleChoice(
          'Style',
          _categories.styles,
          _style,
          (v) => setState(() => _style = v),
        ),
        const SizedBox(height: 12),
        _singleChoice(
          'Mood / lighting',
          _categories.moods,
          _mood,
          (v) => setState(() => _mood = v),
        ),
      ],
    );
  }

  Widget _buildColorsDecorPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose Colors and Decor',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Select palette and decor elements to guide the AI design.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 16),
        _choiceChips('Color palette', _categories.palettes, _palettes, (value) {
          setState(
            () => _palettes.contains(value)
                ? _palettes.remove(value)
                : _palettes.add(value),
          );
        }),
        const SizedBox(height: 16),
        _choiceChips('Decor elements', _categories.decor, _decor, (value) {
          setState(
            () => _decor.contains(value)
                ? _decor.remove(value)
                : _decor.add(value),
          );
        }),
      ],
    );
  }

  Widget _buildVenuePhotosPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Upload Venue Reference Photos',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload venue photos and add notes. The first photo is used as the base image for generation.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickVenuePhotos,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            _venuePhotosB64.isEmpty
                ? 'Upload venue reference photos'
                : 'Add photos (${_venuePhotosB64.length})',
          ),
        ),
        const SizedBox(height: 12),
        if (_venuePhotosB64.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _venuePhotosB64.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_venuePhotosB64[index]),
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: () => setState(() => _venuePhotosB64.removeAt(index)),
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Venue / styling notes',
            hintText: 'e.g. simple wedding setup with garden theme',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratePane(Map<String, dynamic> theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Generate Theme Design',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Generate an AI preview from your style, colors, and venue photo.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_generating ? 'Generating…' : 'Generate theme design'),
          style: FilledButton.styleFrom(
            backgroundColor: _accentYellow,
            foregroundColor: _darkHeader,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (_generateError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _generateError!,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (_generatedUrl != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Generated design (tap to view full screen)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => showThemeDesignFullscreen(context, theme),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _generatedUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => previewThemeDesignPdf(
                  context: context,
                  themeDesign: theme,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Preview PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => saveThemeDesignImageToGallery(
                  context: context,
                  themeDesign: theme,
                ),
                icon: const Icon(Icons.download),
                label: const Text('Download image'),
              ),
            ],
          ),
        ],
        if (_previousUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Previous generations',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _previousUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final url = _previousUrls[i];
                final selected = url == _generatedUrl;
                return GestureDetector(
                  onTap: () => setState(() => _generatedUrl = url),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? _accentYellow : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabContent(Map<String, dynamic> theme) {
    switch (_activeTab) {
      case _ThemeDesignTab.styleMood:
        return _buildStyleMoodPane();
      case _ThemeDesignTab.colorsDecor:
        return _buildColorsDecorPane();
      case _ThemeDesignTab.venuePhotos:
        return _buildVenuePhotosPane();
      case _ThemeDesignTab.generate:
        return _buildGeneratePane(theme);
    }
  }

  Widget _buildSplitBody(Map<String, dynamic> theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSideTabNav(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildTabContent(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveAction() {
    if (_saving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return TextButton(
      onPressed: _save,
      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeDesign();
    final title = widget.eventTitle?.trim().isNotEmpty == true
        ? widget.eventTitle!
        : 'Event theme design';

    if (widget.embedded) {
      return Material(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _darkHeader,
                border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFFC024),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _buildSaveAction(),
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSplitBody(theme)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentYellow,
                    foregroundColor: _darkHeader,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Save design'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [_buildSaveAction()],
      ),
      body: _buildSplitBody(theme),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save design'),
          ),
        ),
      ),
    );
  }
}
