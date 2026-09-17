import 'package:flutter_test/flutter_test.dart';

import 'package:endpoint_monitor/services/process_ai_explain.dart';

void main() {
  test('builds a non-thinking glm-4.7-flash JSON request', () {
    final body = zaiProcessExplainRequestBody(
      systemPrompt: 'system',
      userMessage: 'user',
    );

    expect(kZaiChatCompletionsUrl,
        'https://api.z.ai/api/paas/v4/chat/completions');
    expect(kZaiProcessExplainModel, 'glm-4.7-flash');
    expect(kZaiProcessExplainAttribution, 'Powered by Z.AI · glm-4.7-flash');
    expect(body['model'], 'glm-4.7-flash');
    expect(body['temperature'], 0.2);
    expect(body['max_tokens'], 1024);
    expect(body['thinking'], {'type': 'disabled'});
    expect(body['response_format'], {'type': 'json_object'});
    expect(body.containsKey('do_sample'), isFalse);
    expect(body['messages'], [
      {'role': 'system', 'content': 'system'},
      {'role': 'user', 'content': 'user'},
    ]);
  });

  test('sends Bearer auth and English Accept-Language', () {
    final headers = zaiProcessExplainHeaders('test-key');
    expect(headers['Authorization'], 'Bearer test-key');
    expect(headers['Content-Type'], 'application/json');
    expect(headers['Accept-Language'], 'en-US,en');
  });

  test('detects missing Z.AI API key errors', () {
    expect(isMissingZaiApiKeyError(kMissingZaiApiKeyMessage), isTrue);
    expect(isMissingZaiApiKeyError('Request timed out'), isFalse);
    expect(isMissingZaiApiKeyError(null), isFalse);
  });
}
