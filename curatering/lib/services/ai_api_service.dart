import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'runpod_service.dart';

/// Event theme generation via the Curatering API RunPod proxy.
class ApiService {
  static const Map<String, List<String>> _themeDecorMap = {
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

  static List<String> _themeDecorFor(String value) {
    final lookup = value.toLowerCase();
    return [
      for (final entry in _themeDecorMap.entries)
        if (lookup.contains(entry.key)) ...entry.value,
    ];
  }

  static double _controlnetForDenoise(double denoise) {
    if (denoise < 0.8) return 0.85;
    if (denoise < 0.86) return 0.65;
    return 0.55;
  }

  static Future<Map<String, dynamic>?> generateTheme({
    required File imageFile,
    required String eventType,
    required String colorScheme,
    required String style,
    int guestCount = 50,
    String customPrompt = '',
    String negativePrompt = 'blurry, distorted, unrealistic, poor quality',
    double strength = 0.85,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final initB64 = base64Encode(bytes);
      final themeDecor = _themeDecorFor(style);
      String decorPhrase(String value) {
        final text = value.trim();
        if (text.isEmpty) return '';
        return text.toLowerCase().contains('decor') ? text : '$text decor';
      }

      final prompt =
          StringBuffer()
            ..write(
              'use this venue image to make these edits: $eventType party event',
            )
            ..write(', ')
            ..write('$style style')
            ..write(', ')
            ..write('$colorScheme mood/lighting')
            ..write(', ')
            ..write('$colorScheme color palette')
            ..write(', ')
            ..write(
              (themeDecor.isNotEmpty
                      ? themeDecor
                      : [
                        'round banquet tables',
                        'cream drapery',
                        'floral centerpieces',
                      ])
                  .map(decorPhrase)
                  .join(', '),
            );
      if (customPrompt.trim().isNotEmpty) {
        prompt.write(', ${customPrompt.trim()}');
      }
      prompt.write(', add chairs and tables');

      final eventConfig = {
        'task_type': 'nano_event_design',
        'use_nlp_prompt_expansion': false,
        'event_type': eventType,
        'theme': style,
        'style': style,
        'mood': colorScheme,
        'colors': [colorScheme],
        'color_palette': [colorScheme],
        if (themeDecor.isNotEmpty) ...{
          'decor': themeDecor,
          'decor_elements': themeDecor,
          'theme_tokens': themeDecor,
        },
        'guest_count': guestCount,
        if (customPrompt.trim().isNotEmpty)
          'custom_instructions': customPrompt.trim(),
      };
      final denoise = strength.clamp(0.75, 0.9).toDouble();
      final controlnet = _controlnetForDenoise(denoise);

      final imageUrl = await RunPodService.generateImageWithPolling(
        prompt.toString(),
        initImageBase64: initB64,
        strength: denoise,
        numInferenceSteps: 30,
        guidanceScale: 7,
        designMeta: {
          ...eventConfig,
          'task_type': 'nano_event_design',
          'use_nlp_prompt_expansion': false,
          'controlnet': {
            'enabled': true,
            'preprocessor': 'depth',
            'preserve_venue': true,
            'conditioning_scale': controlnet,
          },
          'controlnet_conditioning_scale': controlnet,
          if (negativePrompt.trim().isNotEmpty)
            'negative_prompt': negativePrompt,
        },
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        return {
          'success': false,
          'error': 'RunPod did not return an image URL',
        };
      }

      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        final res = await http.get(Uri.parse(imageUrl));
        if (res.statusCode != 200) {
          return {
            'success': false,
            'error': 'Failed to download generated image',
          };
        }
        return {
          'success': true,
          'image': base64Encode(res.bodyBytes),
          'imageUrl': imageUrl,
        };
      }

      return {'success': true, 'image': imageUrl};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
