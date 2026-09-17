import 'dart:convert';

import 'package:flutter/material.dart';

import '../../utils/image_pick_limits.dart';
import '../../utils/payment_proof_image.dart' show showPaymentProofLightbox;
import 'event_design_categories.dart';
import 'events_feature_api.dart';
import 'runpod_service.dart';
import 'theme_design_export.dart';

double _controlnetForDenoise(double denoise) {
  if (denoise < 0.8) return 0.85;
  if (denoise < 0.86) return 0.65;
  return 0.55;
}

const Map<String, List<String>> _themeDecorMap = {
  'cinderella': [
    'princess figure wearing royal blue dress',
    'royal blue drapery',
    'glass slipper centerpiece',
    'castle arch backdrop',
    'crystal chandeliers',
  ],
  'rustic': ['wooden tables', 'warm string lights', 'greenery centerpieces'],
  'modern luxury': [
    'gold accents',
    'marble decor',
    'minimalist floral arrangements',
  ],
  'luxury': [
    'crystal chandeliers',
    'white floral centerpieces',
    'gold accents',
    'cream drapery',
  ],
};

List<String> _themeDecorFor(String? value) {
  final lookup = (value ?? '').toLowerCase();
  return [
    for (final entry in _themeDecorMap.entries)
      if (lookup.contains(entry.key)) ...entry.value,
  ];
}

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
  String? _generatedPrompt;
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

  void _clearGeneratedDesignOutputs() {
    _generatedUrl = null;
    _generatedPrompt = null;
    _previousUrls.clear();
    _generateError = null;
  }

  Future<void> _pickVenuePhotos() async {
    final picked = await pickImagesBase64(
      context: context,
      allowMultiple: true,
      maxWidth: 1600,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      final previousPrimary =
          _venuePhotosB64.isNotEmpty ? _venuePhotosB64.first : null;
      final hadGenerated =
          _generatedUrl != null || _previousUrls.isNotEmpty;
      // Any venue reference change invalidates prior generated designs.
      _venuePhotosB64
        ..clear()
        ..addAll(picked);
      final primaryChanged =
          previousPrimary == null || previousPrimary != _venuePhotosB64.first;
      if (primaryChanged || hadGenerated) {
        _clearGeneratedDesignOutputs();
      }
    });
  }

  String _prompt() {
    final mappedDecor = _themeDecorFor(_style);
    final decorValues = [...mappedDecor, ..._decor];
    final eventType = _eventType.trim().isEmpty ? 'event' : _eventType.trim();
    String decorPhrase(String value) {
      final text = value.trim();
      if (text.isEmpty) return '';
      return text.toLowerCase().contains('decor') ? text : '$text decor';
    }

    return [
      'use this venue image to make these edits: $eventType party event',
      if (_style != null && _style!.trim().isNotEmpty)
        '${_style!.trim()} style',
      if (_mood != null && _mood!.trim().isNotEmpty)
        '${_mood!.trim()} mood/lighting',
      if (_palettes.isNotEmpty) '${_palettes.join(', ')} color palette',
      for (final item in decorValues)
        if (decorPhrase(item).isNotEmpty) decorPhrase(item),
      if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
      'add chairs and tables',
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

  Map<String, dynamic> _runpodMeta({EventPromptExpansion? expansion}) {
    final denoise = expansion?.recommendedStrength ?? 0.85;
    final controlnet = _controlnetForDenoise(denoise);
    return {
      ..._eventConfig(),
      'task_type': 'nano_event_design',
      'use_nlp_prompt_expansion': false,
      if (expansion != null) ...expansion.toSdxlMeta(),
      'negative_prompt':
          expansion?.negativePrompt.isNotEmpty == true
              ? expansion!.negativePrompt
              : 'warped architecture, distorted room, melted surfaces, duplicate objects, blurry, low quality, cartoon, CGI, fisheye',
      'controlnet': {
        'enabled': expansion?.controlnet?['enabled'] ?? true,
        'preprocessor': expansion?.controlnet?['preprocessor'] ?? 'depth',
        'preserve_venue': true,
        'conditioning_scale':
            expansion?.controlnet?['conditioning_scale'] ?? controlnet,
      },
      'controlnet_conditioning_scale':
          expansion?.controlnet?['conditioning_scale'] ?? controlnet,
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
      if (_generatedPrompt != null) 'generatedPrompt': _generatedPrompt,
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
      final prompt = _prompt();
      const denoise = 0.85;
      final url = await RunPodService.generateImageWithPolling(
        prompt,
        user_id: widget.userEmail,
        initImageBase64: _venuePhotosB64.first,
        strength: denoise,
        numInferenceSteps: 30,
        guidanceScale: 7,
        designMeta: _runpodMeta(),
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
        _generatedPrompt = prompt;
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
    ValueChanged<String> onToggle, {
    bool enabled = true,
  }) {
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
                onSelected: enabled ? (_) => onToggle(option) : null,
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
    ValueChanged<String?> onChanged, {
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      value: value != null && options.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeDesign();
    final inputsEnabled = !_generating;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventTitle?.trim().isNotEmpty == true
              ? widget.eventTitle!
              : 'Event theme design',
        ),
        actions: [
          if (_saving || _generating)
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
          AbsorbPointer(
            absorbing: !inputsEnabled,
            child: Opacity(
              opacity: inputsEnabled ? 1 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _singleChoice(
                    'Style',
                    _categories.styles,
                    _style,
                    (v) => setState(() => _style = v),
                    enabled: inputsEnabled,
                  ),
                  const SizedBox(height: 12),
                  _singleChoice(
                    'Mood / lighting',
                    _categories.moods,
                    _mood,
                    (v) => setState(() => _mood = v),
                    enabled: inputsEnabled,
                  ),
                  const SizedBox(height: 16),
                  _choiceChips(
                    'Color palette',
                    _categories.palettes,
                    _palettes,
                    (value) {
                      setState(
                        () =>
                            _palettes.contains(value)
                                ? _palettes.remove(value)
                                : _palettes.add(value),
                      );
                    },
                    enabled: inputsEnabled,
                  ),
                  const SizedBox(height: 16),
                  _choiceChips(
                    'Decor elements',
                    _categories.decor,
                    _decor,
                    (value) {
                      setState(
                        () =>
                            _decor.contains(value)
                                ? _decor.remove(value)
                                : _decor.add(value),
                      );
                    },
                    enabled: inputsEnabled,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    enabled: inputsEnabled,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Custom notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: inputsEnabled ? _pickVenuePhotos : null,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _venuePhotosB64.isEmpty
                          ? 'Upload venue photo'
                          : 'Change venue photo(s)',
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
                        itemBuilder: (context, index) {
                          final bytes = base64Decode(_venuePhotosB64[index]);
                          return Stack(
                              children: [
                                Tooltip(
                                  message: 'Tap to enlarge',
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => showPaymentProofLightbox(
                                        context,
                                        bytes,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          bytes,
                                          width: 92,
                                          height: 92,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (inputsEnabled)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () {
                                          setState(() {
                                            _venuePhotosB64.removeAt(index);
                                            _clearGeneratedDesignOutputs();
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                          );
                        },
                      ),
                    ),
                ],
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
          if (_generating) ...[
            const SizedBox(height: 8),
            Text(
              'Please wait — inputs stay locked until the design finishes.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
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
                      _generating
                          ? null
                          : () => previewThemeDesignPdf(
                            context: context,
                            themeDesign: theme,
                          ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Preview PDF'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _generating
                          ? null
                          : () => saveThemeDesignImageToGallery(
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
            onPressed: (_saving || _generating) ? null : _save,
            child: const Text('Save design'),
          ),
        ),
      ),
    );
  }
}
