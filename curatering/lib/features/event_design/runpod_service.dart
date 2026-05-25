import '../../services/runpod_service.dart' as current;

typedef EventPromptExpansion = current.EventPromptExpansion;

class RunPodService {
  RunPodService._();

  static void configure(String apiBase) {
    // The website app uses the central API config in `services/runpod_service.dart`.
  }

  static Future<String?> generateImageWithPolling(
    String prompt, {
    String? user_id,
    String? initImageBase64,
    double strength = 0.58,
    int numInferenceSteps = 30,
    double? guidanceScale,
    Map<String, dynamic>? designMeta,
  }) {
    return current.RunPodService.generateImageWithPolling(
      prompt,
      user_id: user_id,
      initImageBase64: initImageBase64,
      strength: strength,
      numInferenceSteps: numInferenceSteps,
      guidanceScale: guidanceScale,
      designMeta: designMeta,
    );
  }

  static Future<EventPromptExpansion> expandEventPrompt(
    Map<String, dynamic> eventConfig, {
    String fallbackPrompt = '',
  }) {
    return current.RunPodService.expandEventPrompt(
      eventConfig,
      fallbackPrompt: fallbackPrompt,
    );
  }
}
