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
      final prompt = StringBuffer()
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

      final imageUrl = await RunPodService.generateImageWithPolling(
        prompt.toString(),
        initImageBase64: initB64,
        strength: strength.clamp(0.15, 0.95),
        numInferenceSteps: 20,
        designMeta: {
          'event_type': eventType,
          'color_scheme': colorScheme,
          'style': style,
          'guest_count': guestCount,
          if (negativePrompt.trim().isNotEmpty) 'negative_prompt': negativePrompt,
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
