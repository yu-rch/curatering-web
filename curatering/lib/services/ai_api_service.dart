import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "curatering.up.railway.app";

  static Future<Map<String, dynamic>?> generateTheme({
    required File imageFile,
    required String eventType,
    required String colorScheme,
    required String style,
    int guestCount = 50,
    String customPrompt = "",
    String negativePrompt = "blurry, distorted, unrealistic, poor quality",
    double strength = 0.5,
  }) async {
    var uri = Uri.parse("$baseUrl/generate-theme");

    var request = http.MultipartRequest("POST", uri);

    request.fields['event_type'] = eventType;
    request.fields['color_scheme'] = colorScheme;
    request.fields['style'] = style;
    request.fields['guest_count'] = guestCount.toString();
    request.fields['custom_prompt'] = customPrompt;
    request.fields['negative_prompt'] = negativePrompt;
    request.fields['strength'] = strength.toString();

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);

      return {'image': data['image'], 'success': data['success'] ?? true};
    } else {
      print("Error: ${response.statusCode}");
      final respStr = await response.stream.bytesToString();
      try {
        final errorData = jsonDecode(respStr);
        return {
          'image': null,
          'success': false,
          'error': errorData['error'] ?? 'Unknown error',
        };
      } catch (e) {
        return {
          'image': null,
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    }
  }
}
