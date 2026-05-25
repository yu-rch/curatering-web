import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'runpod_service.dart';

/// Event theme generation via the Curatering API RunPod proxy.
class ApiService {
  static Future<Map<String, dynamic>?> generateTheme({
    required File imageFile,
    required String eventType,
    required String colorScheme,
    required String style,
    int guestCount = 50,
    String customPrompt = '',
    String negativePrompt = 'blurry, distorted, unrealistic, poor quality',
    double strength = 0.5,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final initB64 = base64Encode(bytes);
      final prompt =
          StringBuffer()
            ..write('$eventType event design')
            ..write(', $colorScheme color scheme')
            ..write(', $style style')
            ..write(', for $guestCount guests');
      if (customPrompt.trim().isNotEmpty) {
        prompt.write('. $customPrompt');
      }
      prompt.write(
        '. Decorate the venue in the reference photo, preserve layout, realistic lighting.',
      );

      final eventConfig = {
        'task_type': 'event_prompt_expansion',
        'event_type': eventType,
        'theme': style,
        'style': style,
        'mood': colorScheme,
        'colors': [colorScheme],
        'color_palette': [colorScheme],
        'guest_count': guestCount,
        if (customPrompt.trim().isNotEmpty)
          'custom_instructions': customPrompt.trim(),
      };
      final expansion = await RunPodService.expandEventPrompt(
        eventConfig,
        fallbackPrompt: prompt.toString(),
      );

      final imageUrl = await RunPodService.generateImageWithPolling(
        expansion.positivePrompt,
        initImageBase64: initB64,
        strength:
            (expansion.recommendedStrength ?? strength)
                .clamp(0.15, 0.95)
                .toDouble(),
        numInferenceSteps: 20,
        designMeta: {
          ...eventConfig,
          'task_type': 'sdxl_event_design',
          'use_nlp_prompt_expansion': false,
          ...expansion.toSdxlMeta(),
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
