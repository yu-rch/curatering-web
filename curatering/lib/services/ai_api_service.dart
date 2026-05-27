import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'runpod_service.dart';

/// Event theme generation via the Curatering API RunPod proxy.
class ApiService {
  static const Map<String, List<String>> _themeDecorMap = {
    'cinderella': [
      'royal blue dress princess',
      'glass slipper centerpiece',
      'crystal chandeliers',
    ],
    'rustic': [
      'wooden tables',
      'warm string lights',
      'greenery centerpieces',
    ],
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
    if (denoise < 0.55) return 0.85;
    if (denoise < 0.7) return 0.65;
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
    double strength = 0.72,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final initB64 = base64Encode(bytes);
      final themeDecor = _themeDecorFor(style);
      final prompt =
          StringBuffer()
            ..write('transform venue into $style $eventType reception')
            ..write(', ')
            ..write('replace empty floor with banquet tables')
            ..write(', add $colorScheme accents')
            ..write(
              themeDecor.isNotEmpty
                  ? ', ${themeDecor.join(', ')}'
                  : ', round banquet tables, cream drapery, floral centerpieces',
            );
      if (customPrompt.trim().isNotEmpty) {
        prompt.write(', ${customPrompt.trim()}');
      }
      prompt.write(
        ', photorealistic',
      );

      final eventConfig = {
        'task_type': 'event_prompt_expansion',
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
      final expansion = await RunPodService.expandEventPrompt(
        eventConfig,
        fallbackPrompt: prompt.toString(),
      );
      final denoise =
          (expansion.recommendedStrength ?? strength).clamp(0.5, 0.78).toDouble();
      final controlnet = _controlnetForDenoise(denoise);

      final imageUrl = await RunPodService.generateImageWithPolling(
        expansion.positivePrompt,
        initImageBase64: initB64,
        strength: denoise,
        numInferenceSteps: expansion.steps ?? 30,
        guidanceScale: expansion.cfgScale ?? 7,
        designMeta: {
          ...eventConfig,
          'task_type': 'sdxl_event_design',
          'use_nlp_prompt_expansion': false,
          ...expansion.toSdxlMeta(),
          'controlnet':
              expansion.controlnet ??
              {
                'enabled': true,
                'preprocessor': 'canny',
                'preserve_venue': true,
                'conditioning_scale': controlnet,
              },
          'controlnet_conditioning_scale': controlnet,
          if (negativePrompt.trim().isNotEmpty &&
              expansion.negativePrompt.isEmpty)
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
