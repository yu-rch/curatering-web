import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

const Duration _runPostTimeout = Duration(seconds: 120);
const Duration _pollGetTimeout = Duration(seconds: 45);

class EventPromptExpansion {
  const EventPromptExpansion({
    required this.positivePrompt,
    required this.negativePrompt,
    required this.themeTokens,
    required this.lightingTokens,
    required this.styleTokens,
    required this.decorTokens,
    required this.decorElements,
    required this.visualKeywords,
    this.recommendedStrength,
    this.cfgScale,
    this.steps,
    this.controlnet,
    this.mode,
    this.transformationPlan,
  });

  final String positivePrompt;
  final String negativePrompt;
  final List<String> themeTokens;
  final List<String> lightingTokens;
  final List<String> styleTokens;
  final List<String> decorTokens;
  final List<String> decorElements;
  final List<String> visualKeywords;
  final double? recommendedStrength;
  final double? cfgScale;
  final int? steps;
  final Map<String, dynamic>? controlnet;
  final String? mode;
  final Map<String, dynamic>? transformationPlan;

  Map<String, dynamic> toSdxlMeta() {
    return {
      'positive_prompt': positivePrompt,
      if (negativePrompt.isNotEmpty) 'negative_prompt': negativePrompt,
      'theme_tokens': themeTokens,
      'lighting_tokens': lightingTokens,
      'style_tokens': styleTokens,
      'decor_tokens': decorTokens,
      'decor_elements': decorElements,
      'visual_keywords': visualKeywords,
      if (recommendedStrength != null)
        'recommended_strength': recommendedStrength,
      if (recommendedStrength != null) 'strength': recommendedStrength,
      if (cfgScale != null) 'cfg_scale': cfgScale,
      if (steps != null) 'steps': steps,
      if (controlnet != null) 'controlnet': controlnet,
      if (mode != null && mode!.isNotEmpty) 'mode': mode,
      if (transformationPlan != null) 'transformation_plan': transformationPlan,
      'nlp_expansion': toJson(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'positive_prompt': positivePrompt,
      'negative_prompt': negativePrompt,
      'theme_tokens': themeTokens,
      'lighting_tokens': lightingTokens,
      'style_tokens': styleTokens,
      'decor_tokens': decorTokens,
      'decor_elements': decorElements,
      'visual_keywords': visualKeywords,
      if (recommendedStrength != null)
        'recommended_strength': recommendedStrength,
      if (recommendedStrength != null) 'strength': recommendedStrength,
      if (cfgScale != null) 'cfg_scale': cfgScale,
      if (steps != null) 'steps': steps,
      if (controlnet != null) 'controlnet': controlnet,
      if (mode != null && mode!.isNotEmpty) 'mode': mode,
      if (transformationPlan != null) 'transformation_plan': transformationPlan,
    };
  }

  factory EventPromptExpansion.fromJson(
    Map<String, dynamic> json, {
    String fallbackPrompt = '',
  }) {
    List<String> strings(dynamic value) {
      return (value as List? ?? const [])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    double? number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value');
    }

    int? integer(dynamic value) {
      if (value is num) return value.round();
      return int.tryParse('$value');
    }

    Map<String, dynamic>? map(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final positive =
        '${json['positive_prompt'] ?? json['prompt'] ?? fallbackPrompt}'.trim();
    if (positive.isEmpty) {
      throw Exception('NLP prompt expansion returned no positive prompt.');
    }
    return EventPromptExpansion(
      positivePrompt: positive,
      negativePrompt: '${json['negative_prompt'] ?? ''}'.trim(),
      themeTokens: strings(json['theme_tokens']),
      lightingTokens: strings(json['lighting_tokens']),
      styleTokens: strings(json['style_tokens']),
      decorTokens: strings(json['decor_tokens']),
      decorElements: strings(json['decor_elements']),
      visualKeywords: strings(
        json['visual_keywords'] ?? json['visual_direction'],
      ),
      recommendedStrength: number(
        json['recommended_strength'] ?? json['strength'],
      ),
      cfgScale: number(json['cfg_scale']),
      steps: integer(json['steps']),
      controlnet: map(json['controlnet']),
      mode: json['mode']?.toString(),
      transformationPlan: map(json['transformation_plan']),
    );
  }
}

class _RunPodTerminalException implements Exception {
  const _RunPodTerminalException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

  static Uri _statusUri(String jobId) => Uri.parse(
    '$_proxyBase/api/public/runpod/status/${Uri.encodeComponent(jobId)}',
  );

  static Uri _publicNlpRunUri() =>
      Uri.parse('$_proxyBase/api/public/runpod/nlp/run');

  static Uri _publicNlpStatusUri(String jobId) => Uri.parse(
    '$_proxyBase/api/public/runpod/nlp/status/${Uri.encodeComponent(jobId)}',
  );

  static String _normalizeB64(String raw) {
    var s = raw.trim();
    if (s.startsWith('data:')) {
      final comma = s.indexOf(',');
      s = comma >= 0 ? s.substring(comma + 1) : s;
    }
    return s.replaceAll(RegExp(r'\s+'), '');
  }

  static String? _normalizeStatus(dynamic status) {
    if (status == null) return null;
    return status.toString().trim().toUpperCase();
  }

  static bool _isNanoEventDesignInput(Map<String, dynamic> input) {
    final taskType =
        '${input['task_type'] ?? input['task'] ?? ''}'.trim().toLowerCase();
    return taskType == 'nano_event_design';
  }

  static String _nanoResultUrl(String jobId) {
    return 'https://image.runpod.ai/google-nano-banana-2-edit/'
        '${Uri.encodeComponent(jobId)}/result.png';
  }

  static bool _statusIsQueued(String? status) {
    if (status == null) return false;
    return status == 'IN_QUEUE' ||
        status == 'IN_PROGRESS' ||
        status == 'QUEUED' ||
        status == 'RUNNING' ||
        status == 'PROCESSING' ||
        status == 'SUBMITTED';
  }

  static bool _statusIsCompleted(String? status) => status == 'COMPLETED';

  static bool _statusIsFailed(String? status) =>
      status == 'FAILED' || status == 'CANCELLED';

  static String? _extractJobId(Map<String, dynamic> data) {
    final direct = data['id']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final alt = data['jobId']?.toString();
    if (alt != null && alt.isNotEmpty) return alt;
    final job = data['job'];
    if (job is Map) {
      final nested = job['id']?.toString();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    return null;
  }

  static Map<String, dynamic> _map(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static Map<String, dynamic> _extractNlpPayload(Map<String, dynamic> data) {
    final output = _map(data['output']);
    final result = _map(output['result']);
    if (result.isNotEmpty) return result;
    final analysis = _map(output['analysis']);
    if (analysis.isNotEmpty) return analysis;
    if (output.isNotEmpty) return output;
    final nested = _map(data['result']);
    if (nested.isNotEmpty) return nested;
    return data;
  }

  static Future<String?> generateImage(String prompt) async {
    try {
      _ensureBase();
      final response = await http
          .post(
            _runUri(),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'input': {'prompt': prompt},
            }),
          )
          .timeout(_runPostTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = _normalizeStatus(data['status']);

        if (_statusIsCompleted(status)) {
          final imageUrl =
              _imageUrlFromAny(data['output']) ?? _imageUrlFromAny(data);
          if (imageUrl != null) return imageUrl;
          final outputError =
              _runpodOutputError(data['output']) ?? _runpodOutputError(data);
          if (outputError != null) throw _RunPodTerminalException(outputError);
          throw _RunPodTerminalException(_formatNoImageResult(data));
        } else if (_statusIsQueued(status)) {
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

  static Future<EventPromptExpansion> expandEventPrompt(
    Map<String, dynamic> eventConfig, {
    String fallbackPrompt = '',
  }) async {
    try {
      _ensureBase();
      final input = <String, dynamic>{
        ...eventConfig,
        'task_type': 'event_prompt_expansion',
      };
      final response = await http
          .post(
            _publicNlpRunUri(),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'input': input}),
          )
          .timeout(_runPostTimeout);

      if (response.statusCode != 200) {
        _throwHttp(response);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = _normalizeStatus(data['status']);
      final jobId = _extractJobId(data);

      if (_statusIsCompleted(status) || data['output'] != null) {
        return EventPromptExpansion.fromJson(
          _extractNlpPayload(data),
          fallbackPrompt: fallbackPrompt,
        );
      }
      if (_statusIsFailed(status)) {
        throw Exception(_formatRunpodFailure(data));
      }
      if (jobId == null || jobId.isEmpty) {
        throw Exception('NLP prompt expansion did not return a job id.');
      }
      final completed = await _pollPublicNlpForCompletion(jobId);
      return EventPromptExpansion.fromJson(
        _extractNlpPayload(completed),
        fallbackPrompt: fallbackPrompt,
      );
    } catch (e) {
      throw Exception('Failed to expand event prompt: $e');
    }
  }

  static Never _throwHttp(http.Response response) {
    String msg = response.reasonPhrase ?? 'Request failed';
    try {
      final j = jsonDecode(response.body);
      if (j is Map) {
        if (j['code'] == 'runpod_not_configured') {
          throw Exception(
            'AI generation is not configured on the server. Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID on Railway.',
          );
        }
        if (j['message'] != null) {
          msg = '${j['message']}';
        }
      }
    } catch (e) {
      if (e is Exception) throw e;
      if (response.body.isNotEmpty) {
        msg =
            response.body.length > 500
                ? '${response.body.substring(0, 500)}…'
                : response.body;
      }
    }
    throw Exception('HTTP ${response.statusCode}: $msg');
  }

  /// When [initImageBase64] is set, RunPod uses img2img (venue-conditioned generation).
  /// Extract image URL from worker output (including legacy error+uploaded cases).
  static bool _isHttpUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static bool _isDataImage(String value) => value.startsWith('data:image/');

  static String? _imageString(dynamic value, {bool allowBareBase64 = false}) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    if (_isHttpUrl(raw) || _isDataImage(raw)) return raw;
    if (!allowBareBase64) return null;

    final normalized = _normalizeB64(raw);
    if (normalized.length < 100) return null;
    final base64Like = RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(normalized);
    if (!base64Like) return null;
    return 'data:image/png;base64,$normalized';
  }

  /// Extract image URL/data from RunPod responses across SD and Nano workers.
  static String? _imageUrlFromAny(dynamic value) {
    if (value == null) return null;
    if (value is String) return _imageString(value);
    if (value is List) {
      for (final item in value) {
        final image = _imageUrlFromAny(item);
        if (image != null) return image;
      }
      return null;
    }
    if (value is! Map) return null;

    final out = Map<String, dynamic>.from(value);
    for (final key in const [
      'image_url',
      'imageUrl',
      'public_url',
      'publicUrl',
      'url',
      'image',
      'output_url',
      'outputUrl',
      'output_image_url',
      'outputImageUrl',
      'result_url',
      'resultUrl',
      'generated_image_url',
      'generatedImageUrl',
    ]) {
      final direct = _imageString(out[key], allowBareBase64: key == 'image');
      if (direct != null) return direct;
    }
    for (final key in const [
      'image_base64',
      'imageBase64',
      'b64_json',
      'base64',
      'image_data',
      'imageData',
    ]) {
      final direct = _imageString(out[key], allowBareBase64: true);
      if (direct != null) return direct;
    }

    for (final key in const [
      'images',
      'image_urls',
      'imageUrls',
      'artifacts',
      'files',
      'predictions',
    ]) {
      final image = _imageUrlFromAny(out[key]);
      if (image != null) return image;
    }
    for (final key in const ['output', 'result', 'data', 'prediction']) {
      final image = _imageUrlFromAny(out[key]);
      if (image != null) return image;
    }
    final diag = out['diagnostics'];
    if (diag is Map) {
      final image = _imageUrlFromAny(diag);
      if (image != null) return image;
    }
    return null;
  }

  static String? _runpodOutputError(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      for (final item in value) {
        final message = _runpodOutputError(item);
        if (message != null) return message;
      }
      return null;
    }
    if (value is! Map) return null;

    final out = Map<String, dynamic>.from(value);
    final status =
        '${out['status'] ?? out['state'] ?? ''}'.trim().toLowerCase();
    final message =
        '${out['message'] ?? out['error'] ?? out['detail'] ?? ''}'.trim();
    if (status == 'error' ||
        status == 'failed' ||
        status == 'cancelled' ||
        status == 'canceled') {
      return message.isEmpty ? 'Worker returned status $status.' : message;
    }
    if (message.isNotEmpty &&
        RegExp(r'error|failed', caseSensitive: false).hasMatch(message)) {
      return message;
    }
    for (final key in const [
      'output',
      'result',
      'data',
      'diagnostics',
      'errors',
    ]) {
      final nested = _runpodOutputError(out[key]);
      if (nested != null) return nested;
    }
    return null;
  }

  static String _formatNoImageResult(Map<String, dynamic> data) {
    String keysOf(dynamic value) {
      if (value is Map) return value.keys.take(12).join(', ');
      if (value is List) return 'list(${value.length})';
      if (value == null) return 'null';
      return value.runtimeType.toString();
    }

    final status = _normalizeStatus(data['status']) ?? 'UNKNOWN';
    final outputKeys = keysOf(data['output']);
    return 'AI job completed but returned no image URL. '
        'status=$status, output=$outputKeys';
  }

  static Future<String?> generateImageWithPolling(
    String prompt, {
    String? user_id,
    String? initImageBase64,
    double strength = 0.85,
    int numInferenceSteps = 30,
    double? guidanceScale,
    Map<String, dynamic>? designMeta,
  }) async {
    try {
      _ensureBase();
      final input = <String, dynamic>{
        'prompt': prompt,
        'num_inference_steps': numInferenceSteps,
        if (designMeta != null) ...designMeta,
      };
      if (guidanceScale != null) {
        input['guidance_scale'] = guidanceScale;
      }
      final uid = user_id?.trim();
      if (uid != null && uid.isNotEmpty) {
        input['user_id'] = uid;
      }
      // Must be set after designMeta so venue image is never overwritten.
      final init = initImageBase64?.trim();
      if (init != null && init.isNotEmpty) {
        input['init_image_base64'] = _normalizeB64(init);
        input['strength'] = strength;
      }
      final useNanoResultFallback = _isNanoEventDesignInput(input);
      final response = await http
          .post(
            _runUri(),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'input': input}),
          )
          .timeout(_runPostTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = _normalizeStatus(data['status']);
        final jobId = _extractJobId(data);

        if (_statusIsCompleted(status)) {
          final imageUrl =
              _imageUrlFromAny(data['output']) ?? _imageUrlFromAny(data);
          if (imageUrl != null) return imageUrl;
          final outputError =
              _runpodOutputError(data['output']) ?? _runpodOutputError(data);
          if (outputError != null) throw _RunPodTerminalException(outputError);
          if (jobId != null && jobId.isNotEmpty) {
            return await _pollForCompletion(
              jobId,
              fallbackImageUrl:
                  useNanoResultFallback ? _nanoResultUrl(jobId) : null,
            );
          }
          throw _RunPodTerminalException(_formatNoImageResult(data));
        }

        if (jobId != null && jobId.isNotEmpty) {
          return await _pollForCompletion(
            jobId,
            fallbackImageUrl:
                useNanoResultFallback ? _nanoResultUrl(jobId) : null,
          );
        }

        if (_statusIsFailed(status)) {
          throw Exception(_formatRunpodFailure(data));
        }

        throw Exception(
          'Generation failed: ${data['error'] ?? data['message'] ?? 'No job id from RunPod'}',
        );
      } else {
        _throwHttp(response);
      }
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  /// RunPod execution timeout is often 600s; poll long enough for cold GPU + inference.
  static const int _pollIntervalSeconds = 5;
  static const int _maxPollAttempts = 130;

  static String _formatRunpodFailure(Map<String, dynamic> data) {
    final err = data['error']?.toString() ?? 'Unknown error';
    if (err.contains('executionTimeout')) {
      return 'AI generation exceeded the server time limit (~10 min). '
          'Redeploy the RunPod worker image, then try again — the second attempt is usually faster.';
    }
    return 'Job failed: $err';
  }

  static Future<String?> _pollForCompletion(
    String jobId, {
    String? fallbackImageUrl,
  }) async {
    int attempts = 0;
    Object? lastError;

    while (attempts < _maxPollAttempts) {
      await Future.delayed(const Duration(seconds: _pollIntervalSeconds));
      attempts++;

      try {
        final response = await http
            .get(_statusUri(jobId))
            .timeout(_pollGetTimeout);

        if (response.statusCode == 429) {
          throw Exception('Too many requests — wait a moment and try again.');
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = _normalizeStatus(data['status']);

          if (_statusIsCompleted(status)) {
            final imageUrl =
                _imageUrlFromAny(data['output']) ?? _imageUrlFromAny(data);
            if (imageUrl != null) return imageUrl;
            final outputError =
                _runpodOutputError(data['output']) ?? _runpodOutputError(data);
            if (outputError != null)
              throw _RunPodTerminalException(outputError);
            if (fallbackImageUrl != null) return fallbackImageUrl;
            throw _RunPodTerminalException(_formatNoImageResult(data));
          }
          if (_statusIsFailed(status)) {
            throw Exception(_formatRunpodFailure(data));
          }
        }
      } on _RunPodTerminalException {
        rethrow;
      } on Exception catch (e) {
        final msg = e.toString();
        if (msg.contains('Job failed') ||
            msg.contains('AI generation exceeded') ||
            msg.contains('Worker returned')) {
          rethrow;
        }
        lastError = e;
        print('Polling error (attempt $attempts): $e');
      } catch (e) {
        lastError = e;
        print('Polling error (attempt $attempts): $e');
      }
    }

    if (lastError is Exception) {
      throw lastError;
    }
    final totalSeconds = _maxPollAttempts * _pollIntervalSeconds;
    throw Exception(
      'Job timed out after ${totalSeconds}s waiting for the AI worker. Try again in a moment.',
    );
  }

  static Future<Map<String, dynamic>> _pollPublicNlpForCompletion(
    String jobId,
  ) async {
    int attempts = 0;
    Object? lastError;

    while (attempts < _maxPollAttempts) {
      await Future.delayed(const Duration(seconds: _pollIntervalSeconds));
      attempts++;

      try {
        final response = await http
            .get(_publicNlpStatusUri(jobId))
            .timeout(_pollGetTimeout);

        if (response.statusCode == 429) {
          throw Exception('Too many requests — wait a moment and try again.');
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = _normalizeStatus(data['status']);

          if (_statusIsCompleted(status)) return data;
          if (_statusIsFailed(status)) {
            throw Exception(_formatRunpodFailure(data));
          }
        } else {
          _throwHttp(response);
        }
      } on Exception catch (e) {
        final msg = e.toString();
        if (msg.contains('Job failed') ||
            msg.contains('AI generation exceeded') ||
            msg.contains('Worker returned')) {
          rethrow;
        }
        lastError = e;
        print('NLP polling error (attempt $attempts): $e');
      } catch (e) {
        lastError = e;
        print('NLP polling error (attempt $attempts): $e');
      }
    }

    if (lastError is Exception) throw lastError;
    final totalSeconds = _maxPollAttempts * _pollIntervalSeconds;
    throw Exception(
      'NLP task timed out after ${totalSeconds}s waiting for the AI worker. Try again in a moment.',
    );
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
    int maxAttempts = _maxPollAttempts,
    int intervalSeconds = _pollIntervalSeconds,
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
