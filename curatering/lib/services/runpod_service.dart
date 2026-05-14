import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Calls the Curatering API RunPod proxy ([`/api/public/runpod/run`], status).
/// `RUNPOD_API_KEY` / `RUNPOD_ENDPOINT_ID` live only on the server (e.g. Railway).
class RunPodService {
  static String get _proxyBase {
    final b = apiBaseUrl.trim();
    if (b.isEmpty) return '';
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  static void _ensureBase() {
    if (_proxyBase.isEmpty) {
      throw Exception(
        'API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached.',
      );
    }
  }

  static Uri _runUri() => Uri.parse('$_proxyBase/api/public/runpod/run');

  static Uri _statusUri(String jobId) =>
      Uri.parse('$_proxyBase/api/public/runpod/status/${Uri.encodeComponent(jobId)}');

  static Future<String?> generateImage(String prompt) async {
    try {
      _ensureBase();
      final response = await http.post(
        _runUri(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'prompt': prompt},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'COMPLETED') {
          final out = data['output'];
          if (out is Map<String, dynamic>) {
            return out['image'] as String?;
          }
          return null;
        } else if (data['status'] == 'IN_PROGRESS' ||
            data['status'] == 'IN_QUEUE') {
          return null;
        } else {
          throw Exception(
            'Generation failed: ${data['error'] ?? 'Unknown error'}',
          );
        }
      } else {
        _throwHttp(response);
      }
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  static Never _throwHttp(http.Response response) {
    String msg = response.reasonPhrase ?? 'Request failed';
    try {
      final j = jsonDecode(response.body);
      if (j is Map && j['message'] != null) {
        msg = '${j['message']}';
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        msg = response.body.length > 500
            ? '${response.body.substring(0, 500)}…'
            : response.body;
      }
    }
    throw Exception('HTTP ${response.statusCode}: $msg');
  }

  static Future<String?> generateImageWithPolling(
    String prompt, {
    required String user_id,
  }) async {
    try {
      _ensureBase();
      final response = await http.post(
        _runUri(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'prompt': prompt, 'user_id': user_id},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'COMPLETED') {
          final out = data['output'];
          if (out is Map && out['status'] == 'error') {
            throw Exception(
              out['message']?.toString() ?? 'Worker returned status error',
            );
          }
          return out is Map ? out['image_url'] as String? : null;
        } else if (data['status'] == 'IN_PROGRESS' ||
            data['status'] == 'IN_QUEUE') {
          final jobId = data['id']?.toString();
          if (jobId == null || jobId.isEmpty) {
            throw Exception('RunPod response missing job id');
          }
          return await _pollForCompletion(jobId);
        } else {
          throw Exception(
            'Generation failed: ${data['error'] ?? 'Unknown error'}',
          );
        }
      } else {
        _throwHttp(response);
      }
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  static Future<String?> _pollForCompletion(String jobId) async {
    int attempts = 0;
    const maxAttempts = 30;

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;

      try {
        final response = await http.get(_statusUri(jobId));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          if (data['status'] == 'COMPLETED') {
            final out = data['output'];
            if (out is Map && out['status'] == 'error') {
              throw Exception(
                out['message']?.toString() ?? 'Worker returned status error',
              );
            }
            return out is Map ? out['image_url'] as String? : null;
          } else if (data['status'] == 'FAILED') {
            throw Exception('Job failed: ${data['error'] ?? 'Unknown error'}');
          }
        }
      } catch (e) {
        print('Polling error (attempt $attempts): $e');
      }
    }

    throw Exception('Job timed out after ${maxAttempts * 2} seconds');
  }

  static Future<Map<String, dynamic>> startGenerationJob(String prompt) async {
    _ensureBase();
    final response = await http.post(
      _runUri(),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'prompt': prompt},
      }),
    );

    if (response.statusCode != 200) {
      _throwHttp(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    _ensureBase();
    final response = await http.get(_statusUri(jobId));

    if (response.statusCode != 200) {
      _throwHttp(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<String?> pollForResult(
    String jobId, {
    int maxAttempts = 30,
    int intervalSeconds = 2,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(Duration(seconds: intervalSeconds));

      try {
        final status = await getJobStatus(jobId);

        if (status['status'] == 'COMPLETED') {
          final out = status['output'];
          if (out is Map<String, dynamic>) {
            return out['image'] as String?;
          }
          return null;
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

  static Future<String?> generateImageWithPollingSimple(String prompt) async {
    final jobResult = await startGenerationJob(prompt);
    final jobId = jobResult['id'] as String;

    return await pollForResult(jobId);
  }
}
