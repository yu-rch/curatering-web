import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RunPodService {
  static String get _endpointId {
    final endpointId = dotenv.env['RUNPOD_ENDPOINT_ID'];
    if (endpointId == null || endpointId.isEmpty) {
      throw Exception('RUNPOD_ENDPOINT_ID environment variable is not set');
    }
    return endpointId;
  }

  static String get _apiKey {
    final apiKey = dotenv.env['RUNPOD_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('RUNPOD_API_KEY environment variable is not set');
    }
    return apiKey;
  }

  static const String _baseUrl = 'https://api.runpod.ai/v2';

  static Future<String?> generateImage(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$_endpointId/run'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'input': {'prompt': prompt},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'COMPLETED') {
          return data['output']['image'] as String?; // base64 string
        } else if (data['status'] == 'IN_PROGRESS' ||
            data['status'] == 'IN_QUEUE') {
          // Job is still processing, you might want to implement polling
          return null;
        } else {
          throw Exception(
            'Generation failed: ${data['error'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  static Future<String?> generateImageWithPolling(
    String prompt, {
    required String user_id,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$_endpointId/run'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'input': {'prompt': prompt, 'user_id': user_id},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final jobId = data['id'];

        if (data["status"] == "COMPLETED") {
          return data["output"]["image_url"]; // Return image URL directly
        } else if (data["status"] == "IN_PROGRESS" ||
            data["status"] == "IN_QUEUE") {
          // Poll for completion
          return await _pollForCompletion(jobId);
        } else {
          throw Exception(
            'Generation failed: ${data["error"] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  static Future<String?> _pollForCompletion(String jobId) async {
    int attempts = 0;
    const maxAttempts = 30; // Poll for max 60 seconds (2s intervals)

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/$_endpointId/status/$jobId'),
          headers: {'Authorization': 'Bearer $_apiKey'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data["status"] == "COMPLETED") {
            return data["output"]["image_url"]; // Return image URL
          } else if (data["status"] == "FAILED") {
            throw Exception('Job failed: ${data["error"] ?? 'Unknown error'}');
          }
        }
      } catch (e) {
        print('Polling error (attempt $attempts): $e');
      }
    }

    throw Exception('Job timed out after ${maxAttempts * 2} seconds');
  }

  static Future<Map<String, dynamic>> startGenerationJob(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$_endpointId/run'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'input': {'prompt': prompt},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to start generation: $e');
    }
  }

  static Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_endpointId/status/$jobId'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Failed to get job status: $e');
    }
  }

  static Future<String?> pollForResult(
    String jobId, {
    int maxAttempts = 30,
    int intervalSeconds = 2,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(Duration(seconds: intervalSeconds));

      try {
        final status = await getJobStatus(jobId);

        if (status['status'] == 'COMPLETED') {
          return status['output']['image'] as String?;
        } else if (status['status'] == 'FAILED') {
          throw Exception('Job failed: ${status['error'] ?? 'Unknown error'}');
        }

        print(
          'Job $jobId status: ${status['status']} (attempt ${i + 1}/$maxAttempts)',
        );
      } catch (e) {
        print('Polling error (attempt ${i + 1}/$maxAttempts): $e');
        if (i == maxAttempts - 1) rethrow;
      }
    }

    throw Exception('Job timed out after $maxAttempts attempts');
  }

  // Complete generation with polling
  static Future<String?> generateImageWithPollingSimple(String prompt) async {
    final jobResult = await startGenerationJob(prompt);
    final jobId = jobResult['id'] as String;

    return await pollForResult(jobId);
  }
}
