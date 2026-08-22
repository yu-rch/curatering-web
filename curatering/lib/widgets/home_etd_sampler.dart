import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/home_default_assets.dart';
import '../services/runpod_service.dart';

/// Compact interactive Event Theme Design sampler for the homepage Catering panel.
class HomeEtdSampler extends StatefulWidget {
  const HomeEtdSampler({super.key, this.compact = true});

  final bool compact;

  @override
  State<HomeEtdSampler> createState() => _HomeEtdSamplerState();
}

class _HomeEtdSamplerState extends State<HomeEtdSampler> {
  static const _accentYellow = Color(0xFFFFC024);
  static const _styles = ['Elegant', 'Rustic', 'Modern', 'Garden'];
  static const _moods = ['Romantic', 'Bright', 'Dramatic', 'Cozy'];

  String? _selectedStyle;
  String? _selectedMood;
  String? _venuePhotoBase64;
  int? _selectedSampleIndex;
  String? _generatedImageUrl;
  String? _error;
  bool _generating = false;

  Future<String?> _encodeVenueForRunpod(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 768);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (data == null) return base64Encode(bytes);
      return base64Encode(data.buffer.asUint8List());
    } catch (_) {
      return base64Encode(bytes);
    }
  }

  String _normalizeVenueB64(String raw) {
    var s = raw.trim();
    if (s.startsWith('data:')) {
      final comma = s.indexOf(',');
      s = comma >= 0 ? s.substring(comma + 1) : s;
    }
    return s.replaceAll(RegExp(r'\s+'), '');
  }

  Future<String?> _resolveRunpodUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('customer_data');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final id = data['id']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _eventDesignConfig() {
    final style = _selectedStyle?.trim() ?? '';
    final mood = _selectedMood?.trim() ?? '';
    return {
      'task_type': 'event_prompt_expansion',
      'event_type': 'celebration',
      if (style.isNotEmpty) ...{'theme': style, 'style': style},
      if (mood.isNotEmpty) 'mood': mood,
      'formality': 'casual',
    };
  }

  String _composeFallbackPrompt() {
    final style = _selectedStyle?.trim() ?? '';
    final mood = _selectedMood?.trim() ?? '';
    return <String>[
      'celebration event venue',
      if (style.isNotEmpty) '$style theme',
      if (mood.isNotEmpty) '$mood atmosphere',
      'photorealistic event styling',
      'luxury interior photography',
      'realistic venue decorations',
      'cinematic lighting',
      'ultra detailed',
    ].join(', ');
  }

  String _negativePrompt() {
    return [
      'warped architecture',
      'distorted room',
      'melted surfaces',
      'duplicate objects',
      'blurry',
      'low quality',
      'cartoon',
      'CGI',
      'fisheye',
    ].join(', ');
  }

  Map<String, dynamic> _runpodMeta(EventPromptExpansion expansion) {
    final config = _eventDesignConfig();
    return {
      ...config,
      'task_type': 'sdxl_event_design',
      'use_nlp_prompt_expansion': false,
      ...expansion.toSdxlMeta(),
      'negative_prompt': _negativePrompt(),
      'guidance_scale': 6.5,
      'controlnet': {
        'enabled': true,
        'preprocessor': 'canny',
        'preserve_venue': true,
        'conditioning_scale': 0.65,
      },
      'controlnet_conditioning_scale': 0.65,
    };
  }

  Future<void> _selectSampleVenue(int index) async {
    setState(() => _error = null);
    try {
      final data = await rootBundle.load(HomeDefaultAssets.etdSamples[index]);
      final bytes = data.buffer.asUint8List();
      final b64 = await _encodeVenueForRunpod(bytes);
      if (!mounted || b64 == null) return;
      setState(() {
        _selectedSampleIndex = index;
        _venuePhotoBase64 = b64;
        _generatedImageUrl = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load sample venue.');
    }
  }

  Future<void> _pickVenuePhoto() async {
    setState(() => _error = null);
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          setState(() => _error = 'Image size should be less than 5MB');
        }
        return;
      }
      final b64 = await _encodeVenueForRunpod(bytes);
      if (!mounted || b64 == null) return;
      setState(() {
        _selectedSampleIndex = null;
        _venuePhotoBase64 = b64;
        _generatedImageUrl = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to upload photo: $e');
    }
  }

  Future<void> _generate() async {
    if (_selectedStyle == null || _selectedMood == null) {
      setState(() => _error = 'Select a style and mood first.');
      return;
    }
    final venueRaw = _venuePhotoBase64?.trim();
    if (venueRaw == null || venueRaw.isEmpty) {
      setState(
        () => _error =
            'Upload a venue photo first — the AI uses it as the base image.',
      );
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final fallbackPrompt = _composeFallbackPrompt();
      final venueB64 = _normalizeVenueB64(venueRaw);
      final expansion = await RunPodService.expandEventPrompt(
        _eventDesignConfig(),
        fallbackPrompt: fallbackPrompt,
      );
      final runpodUserId = await _resolveRunpodUserId();
      final imageUrl = await RunPodService.generateImageWithPolling(
        expansion.positivePrompt,
        user_id: runpodUserId,
        initImageBase64: venueB64,
        strength: 0.58,
        numInferenceSteps: 30,
        guidanceScale: 6.5,
        designMeta: _runpodMeta(expansion),
      );
      if (!mounted) return;
      if (imageUrl != null) {
        setState(() {
          _generatedImageUrl = imageUrl;
          _error = null;
        });
      } else {
        setState(() => _error = 'Failed to generate design. Please try again.');
      }
    } catch (e) {
      final raw = e.toString();
      final msg = raw.contains('Exception:')
          ? raw.split('Exception:').last.trim()
          : raw;
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Widget _chipRow({
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelected,
    required bool enabled,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: options.map((label) {
        final isOn = selected == label;
        return ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: isOn,
          onSelected: enabled
              ? (v) {
                  if (v) onSelected(label);
                }
              : null,
          selectedColor: _accentYellow,
          labelStyle: TextStyle(
            color: isOn ? const Color(0xFF1E1E1E) : Colors.white70,
            fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
          backgroundColor: const Color(0xFF3A3A3A),
          side: BorderSide(
            color: isOn ? _accentYellow : Colors.white24,
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }

  Widget _preview() {
    final gen = _generatedImageUrl?.trim() ?? '';
    final venue = _venuePhotoBase64?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: gen.isNotEmpty
            ? Image.network(
                gen,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _previewPlaceholder(
                  'Generated preview unavailable',
                ),
              )
            : venue.isNotEmpty
                ? Image.memory(
                    base64Decode(venue),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : _previewPlaceholder('Select a venue photo to start'),
      ),
    );
  }

  Widget _previewPlaceholder(String message) {
    return Container(
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration_outlined, color: Colors.white54, size: 28),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputsEnabled = !_generating;
    final canGenerate = !_generating &&
        _selectedStyle != null &&
        _selectedMood != null;
    final pad = widget.compact ? 12.0 : 16.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Event Theme Design',
            style: TextStyle(
              color: _accentYellow,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Try a quick sample',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _preview(),
          const SizedBox(height: 10),
          AbsorbPointer(
            absorbing: !inputsEnabled,
            child: Opacity(
              opacity: inputsEnabled ? 1 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Style',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _chipRow(
                    options: _styles,
                    selected: _selectedStyle,
                    enabled: inputsEnabled,
                    onSelected: (v) => setState(() => _selectedStyle = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mood',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _chipRow(
                    options: _moods,
                    selected: _selectedMood,
                    enabled: inputsEnabled,
                    onSelected: (v) => setState(() => _selectedMood = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select venue photo',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: inputsEnabled
                                ? () => _selectSampleVenue(i)
                                : null,
                            child: AspectRatio(
                              aspectRatio: 1.2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedSampleIndex == i
                                        ? _accentYellow
                                        : Colors.white24,
                                    width: _selectedSampleIndex == i ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.asset(
                                    HomeDefaultAssets.etdSamples[i],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: inputsEnabled ? _pickVenuePhoto : null,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text(
                      _venuePhotoBase64 != null && _selectedSampleIndex == null
                          ? 'Change venue photo'
                          : 'Or choose from device',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentYellow,
                      side: BorderSide(
                        color: _venuePhotoBase64 != null
                            ? Colors.green
                            : _accentYellow.withValues(alpha: 0.7),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null && _error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: canGenerate ? _generate : null,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1E1E1E),
                    ),
                  )
                : const Icon(Icons.auto_fix_high, size: 18),
            label: Text(
              _generating ? 'Generating…' : 'Generate sample',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _accentYellow,
              foregroundColor: const Color(0xFF1E1E1E),
              disabledBackgroundColor: _accentYellow.withValues(alpha: 0.6),
            ),
          ),
          if (_generating) ...[
            const SizedBox(height: 6),
            const Text(
              'Please wait — inputs stay locked until the design finishes.',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
