import 'dart:convert';

import 'package:flutter/material.dart';

import '../../utils/image_pick_limits.dart';
import 'event_design_categories.dart';
import 'events_feature_api.dart';
import 'runpod_service.dart';
import 'theme_design_export.dart';

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

  @override
  State<EventThemeDesignScreen> createState() => _EventThemeDesignScreenState();
}

class _EventThemeDesignScreenState extends State<EventThemeDesignScreen> {
  late final String _eventType;
  EventDesignCategories _categories = EventDesignCategories.defaults;
  String? _style;
  String? _mood;
  final Set<String> _palettes = {};
  final Set<String> _decor = {};
  final TextEditingController _notes = TextEditingController();
  final List<String> _venuePhotosB64 = [];
  final List<String> _previousUrls = [];
  String? _generatedUrl;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload a venue photo before generating.'),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final url = await RunPodService.generateImageWithPolling(
        _prompt(),
        user_id: widget.userEmail,
        initImageBase64: _venuePhotosB64.first,
        strength: 0.58,
        numInferenceSteps: 30,
        guidanceScale: 6.5,
        designMeta: {
          'task_type': 'event_design_image',
          'use_nlp_prompt_expansion': true,
          'event_type': _eventType,
          'theme': _style,
          'style': _style,
          'mood': _mood,
          'colors': _palettes.toList(),
          'decor': _decor.toList(),
          'notes': _notes.text.trim(),
          'negative_prompt':
              'warped architecture, distorted room, melted surfaces, duplicate objects, blurry, low quality, cartoon, CGI, fisheye',
          'controlnet': {
            'enabled': true,
            'preprocessor': 'canny',
            'preserve_venue': true,
            'conditioning_scale': 0.65,
          },
          'controlnet_conditioning_scale': 0.65,
        },
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
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
      initialValue: value != null && options.contains(value) ? value : null,
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

  @override
  Widget build(BuildContext context) {
    final theme = _themeDesign();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventTitle?.trim().isNotEmpty == true
              ? widget.eventTitle!
              : 'Event theme design',
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 16),
          _choiceChips('Color palette', _categories.palettes, _palettes, (
            value,
          ) {
            setState(
              () =>
                  _palettes.contains(value)
                      ? _palettes.remove(value)
                      : _palettes.add(value),
            );
          }),
          const SizedBox(height: 16),
          _choiceChips('Decor elements', _categories.decor, _decor, (value) {
            setState(
              () =>
                  _decor.contains(value)
                      ? _decor.remove(value)
                      : _decor.add(value),
            );
          }),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Custom notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickVenuePhotos,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _venuePhotosB64.isEmpty
                  ? 'Upload venue photo'
                  : 'Add venue photos (${_venuePhotosB64.length})',
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
                itemBuilder:
                    (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_venuePhotosB64[index]),
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon:
                _generating
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.auto_awesome),
            label: Text(
              _generating ? 'Generating...' : 'Generate event design',
            ),
          ),
          const SizedBox(height: 16),
          if (_generatedUrl != null) ...[
            InkWell(
              onTap: () => showThemeDesignFullscreen(context, theme),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _generatedUrl!,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      () => previewThemeDesignPdf(
                        context: context,
                        themeDesign: theme,
                      ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Preview PDF'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => saveThemeDesignImageToGallery(
                        context: context,
                        themeDesign: theme,
                      ),
                  icon: const Icon(Icons.download),
                  label: const Text('Download image'),
                ),
              ],
            ),
          ],
        ],
      ),
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
