/// Z.AI GLM-4.7-Flash request contract for Process AI Explain.
library;

import '../settings/zai_api_key.dart';

const String kZaiChatCompletionsUrl =
    'https://api.z.ai/api/paas/v4/chat/completions';

const String kZaiProcessExplainModel = 'glm-4.7-flash';

const String kZaiProcessExplainAttribution = 'Powered by Z.AI · glm-4.7-flash';

const String kMissingZaiApiKeyMessage = 'Process AI explain is unavailable.';

const double kZaiProcessExplainTemperature = 0.2;

const int kZaiProcessExplainMaxTokens = 1024;

/// Project key from `--dart-define=ZAI_API_KEY=...`, else the gitignored local file.
String resolveZaiApiKey() {
  const fromEnv = String.fromEnvironment('ZAI_API_KEY');
  if (fromEnv.trim().isNotEmpty) return fromEnv.trim();
  return kEmbeddedZaiApiKey.trim();
}

Map<String, String> zaiProcessExplainHeaders(String apiKey) {
  return {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    'Accept-Language': 'en-US,en',
  };
}

Map<String, dynamic> zaiProcessExplainRequestBody({
  required String systemPrompt,
  required String userMessage,
}) {
  return {
    'model': kZaiProcessExplainModel,
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ],
    'thinking': {'type': 'disabled'},
    'temperature': kZaiProcessExplainTemperature,
    'max_tokens': kZaiProcessExplainMaxTokens,
    'response_format': {'type': 'json_object'},
  };
}

bool isMissingZaiApiKeyError(String? rawError) {
  return rawError == kMissingZaiApiKeyMessage;
}
