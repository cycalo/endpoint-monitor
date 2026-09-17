# Z.AI GLM-4.7-Flash Process Explain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Do not start this plan until the user says to implement it. Do not create git commits unless the user explicitly asks.

**Goal:** Replace Groq with Z.AI `glm-4.7-flash` for Process AI Explain and remove Groq completely.

**Architecture:** Keep the existing Flutter Explain Process UI, JSON schema, cache, prompt, and Dio call site. Extract a small request-contract helper so the Z.AI URL, model, thinking-off, temperature, max_tokens, headers, and missing-key copy can be unit-tested. Settings stores a new `zai_api_key` in FlutterSecureStorage and deletes any leftover `groq_api_key`.

**Tech Stack:** Flutter/Dart, Dio, FlutterSecureStorage, flutter_test

## Global Constraints

- Endpoint: `https://api.z.ai/api/paas/v4/chat/completions`
- Model: `glm-4.7-flash`
- Thinking: `{ "type": "disabled" }`
- `temperature`: `0.2`
- `max_tokens`: `1024`
- `response_format`: `{ "type": "json_object" }`
- Header `Accept-Language: en-US,en`
- Auth header: `Authorization: Bearer <key>`
- Connect and receive timeout: 20 seconds
- Do not set `do_sample: false`
- Secure storage key: `zai_api_key` (do not reuse or copy `groq_api_key`)
- Attribution copy: `Powered by Z.AI · glm-4.7-flash`
- Settings section title: `Z.AI`
- Settings deep link: `/settings?section=zai`
- No Groq fallback, no streaming, no JSON schema or UI layout change
- Do not raise temperature toward Z.AI's default `1.0`

---

## File structure

- Create: `flutter_app/lib/services/process_ai_explain.dart` — Z.AI URL, headers, request body, missing-key copy
- Create: `flutter_app/test/process_ai_explain_test.dart` — contract tests
- Modify: `flutter_app/lib/settings/app_settings_keys.dart` — replace Groq key with `zaiApiKey`; keep a retired Groq key name only for delete-on-load
- Modify: `flutter_app/lib/screens/process_detail_screen.dart` — call Z.AI, rename Groq helpers/copy
- Modify: `flutter_app/lib/screens/settings_screen.dart` — Z.AI settings section
- Modify: `README.md` — drop Groq, document Z.AI
- Modify: `AGENT_ONBOARDING.md` — replace Groq nodes/edges in the mermaid diagram

---

### Task 1: Z.AI request contract helper

**Files:**
- Create: `flutter_app/lib/services/process_ai_explain.dart`
- Test: `flutter_app/test/process_ai_explain_test.dart`

**Interfaces:**
- Consumes: none
- Produces:
  - `const String kZaiChatCompletionsUrl`
  - `const String kZaiProcessExplainModel`
  - `const String kZaiProcessExplainAttribution`
  - `const String kMissingZaiApiKeyMessage`
  - `const double kZaiProcessExplainTemperature`
  - `const int kZaiProcessExplainMaxTokens`
  - `Map<String, String> zaiProcessExplainHeaders(String apiKey)`
  - `Map<String, dynamic> zaiProcessExplainRequestBody({required String systemPrompt, required String userMessage})`
  - `bool isMissingZaiApiKeyError(String? rawError)`

- [ ] **Step 1: Write the failing test**

Create `flutter_app/test/process_ai_explain_test.dart`:

```dart
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

  test('detects missing Z.AI API key setup errors', () {
    expect(isMissingZaiApiKeyError(kMissingZaiApiKeyMessage), isTrue);
    expect(isMissingZaiApiKeyError('No Z.AI API key configured'), isTrue);
    expect(isMissingZaiApiKeyError('Request timed out'), isFalse);
    expect(isMissingZaiApiKeyError(null), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from `flutter_app/`:

```bash
flutter test test/process_ai_explain_test.dart
```

Expected: FAIL because `lib/services/process_ai_explain.dart` does not exist (or symbols are missing).

- [ ] **Step 3: Write minimal implementation**

Create `flutter_app/lib/services/process_ai_explain.dart`:

```dart
/// Z.AI GLM-4.7-Flash request contract for Process AI Explain.
library;

const String kZaiChatCompletionsUrl =
    'https://api.z.ai/api/paas/v4/chat/completions';

const String kZaiProcessExplainModel = 'glm-4.7-flash';

const String kZaiProcessExplainAttribution = 'Powered by Z.AI · glm-4.7-flash';

const String kMissingZaiApiKeyMessage =
    'No Z.AI API key configured — add your key in Settings → Z.AI';

const double kZaiProcessExplainTemperature = 0.2;

const int kZaiProcessExplainMaxTokens = 1024;

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
  return rawError?.toLowerCase().contains('no z.ai api key') ?? false;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run from `flutter_app/`:

```bash
flutter test test/process_ai_explain_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

Skip unless the user asked to commit.

```bash
git add flutter_app/lib/services/process_ai_explain.dart flutter_app/test/process_ai_explain_test.dart
git commit -m "$(cat <<'EOF'
Add Z.AI glm-4.7-flash request contract for process explain.

EOF
)"
```

---

### Task 2: Wire Explain Process to Z.AI and remove Groq from the call site

**Files:**
- Modify: `flutter_app/lib/settings/app_settings_keys.dart`
- Modify: `flutter_app/lib/screens/process_detail_screen.dart`

**Interfaces:**
- Consumes: Task 1 symbols (`kZaiChatCompletionsUrl`, `kZaiProcessExplainAttribution`, `kMissingZaiApiKeyMessage`, `zaiProcessExplainHeaders`, `zaiProcessExplainRequestBody`, `isMissingZaiApiKeyError`)
- Produces:
  - `AppSettingsKeys.zaiApiKey` = `'zai_api_key'`
  - `AppSettingsKeys.retiredGroqApiKey` = `'groq_api_key'` (delete-only; never read as the live key)
  - `ExplainResult.needsZaiApiKeySetup`
  - Parser name `_parseProcessExplanationFromContent`

- [ ] **Step 1: Replace the Groq storage key**

In `flutter_app/lib/settings/app_settings_keys.dart`, replace:

```dart
  /// FlutterSecureStorage key for optional Groq API key (process AI explain).
  static const groqApiKey = 'groq_api_key';
```

with:

```dart
  /// FlutterSecureStorage key for optional Z.AI API key (process AI explain).
  static const zaiApiKey = 'zai_api_key';

  /// Retired Groq storage key; deleted on Settings load so it is not left behind.
  static const retiredGroqApiKey = 'groq_api_key';
```

Do not copy any value from `groq_api_key` into `zai_api_key`.

- [ ] **Step 2: Import the helper and retarget the Dio call**

In `flutter_app/lib/screens/process_detail_screen.dart`, add this import with the other `../` imports:

```dart
import '../services/process_ai_explain.dart';
```

Rename `_parseProcessExplanationFromGroqContent` to `_parseProcessExplanationFromContent` (function name only; keep the parser body).

Replace `ExplainResult.needsGroqApiKeySetup` with:

```dart
  bool get needsZaiApiKeySetup =>
      isError && isMissingZaiApiKeyError(rawError);
```

In `_plainTextAiReport`, replace both:

```dart
    buf.writeln('Powered by Groq · llama-3.3-70b-versatile');
```

with:

```dart
    buf.writeln(kZaiProcessExplainAttribution);
```

In `_explain()`, replace the Groq key read / empty-key error / POST with:

```dart
    final key = (await storage.read(key: AppSettingsKeys.zaiApiKey) ?? '').trim();
    if (key.isEmpty) {
      _explainCache[widget.pid] = ExplainResult(
        rawError: kMissingZaiApiKeyMessage,
        timestamp: DateTime.now(),
        isError: true,
      );
      _persistExplainCache();
      if (mounted) setState(() {});
      return;
    }
```

Keep the existing 20-second Dio timeouts. Replace the POST target and body:

```dart
      final res = await dio.post<Map<String, dynamic>>(
        kZaiChatCompletionsUrl,
        data: zaiProcessExplainRequestBody(
          systemPrompt: prompt,
          userMessage: userMsg,
        ),
        options: Options(
          headers: zaiProcessExplainHeaders(key),
        ),
      );
```

Keep parsing via `_parseProcessExplanationFromContent(content)`.

Replace the 401 message:

```dart
          errStr = 'Invalid Z.AI API key — check the key saved in Settings';
```

Replace the missing-key CTA:

```dart
                    if (res.needsZaiApiKeySetup) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.push('/settings?section=zai'),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Add Z.AI API key in Settings'),
                      ),
                    ],
```

Replace the on-screen footer:

```dart
                    '$kZaiProcessExplainAttribution\nAI analysis is a guide only\nVerify findings independently',
```

Do not change the system prompt, user message fields, JSON schema, cache, or layout.

- [ ] **Step 3: Confirm the file no longer mentions Groq**

Search `flutter_app/lib/screens/process_detail_screen.dart` for `groq` / `Groq`. Expected: no matches.

- [ ] **Step 4: Commit**

Skip unless the user asked to commit.

```bash
git add flutter_app/lib/settings/app_settings_keys.dart flutter_app/lib/screens/process_detail_screen.dart
git commit -m "$(cat <<'EOF'
Switch process AI explain from Groq to Z.AI glm-4.7-flash.

EOF
)"
```

---

### Task 3: Settings UI

**Files:**
- Modify: `flutter_app/lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `AppSettingsKeys.zaiApiKey`, `AppSettingsKeys.retiredGroqApiKey`
- Produces: Settings section titled `Z.AI` that reads/writes `zai_api_key` and scrolls on `focusSection == 'zai'`

- [ ] **Step 1: Rename Groq section state to Z.AI**

In `_SettingsScreenState`, replace Groq fields and helpers with:

```dart
  /// When set (e.g. `zai`), scrolls to that section after the first frame.
```

(that comment lives on `SettingsScreen.focusSection`)

```dart
  final _zaiSectionKey = GlobalKey();
  final _endpoint = TextEditingController();
  final _jwt = TextEditingController();
  final _zaiApiKey = TextEditingController();
  bool _hideJwt = true;
  bool _hideZaiApi = true;
```

```dart
  String _savedZaiApi = '';
```

```dart
    if (widget.focusSection == 'zai') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToZaiSection());
    }
```

```dart
  void _scrollToZaiSection() {
    if (!mounted) return;
    final ctx = _zaiSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.08,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
```

```dart
    _zaiApiKey.dispose();
```

```dart
  bool get _zaiDirty => _zaiApiKey.text.trim() != _savedZaiApi;
```

- [ ] **Step 2: Read/write `zai_api_key` and delete leftover Groq key**

Replace the Groq load/save block inside `_load()` / `_saveGroqApiKey()` with:

```dart
    await s.delete(key: AppSettingsKeys.retiredGroqApiKey);
    final zaiKey = (await s.read(key: AppSettingsKeys.zaiApiKey) ?? '').trim();
    _endpoint.text = host;
    _jwt.text = token.isEmpty ? '' : _maskToken(token);
    _zaiApiKey.text = zaiKey;
```

and later in `_load()`:

```dart
    _savedZaiApi = zaiKey.trim();
```

```dart
  Future<void> _saveZaiApiKey() async {
    const s = FlutterSecureStorage();
    final key = _zaiApiKey.text.trim();
    if (key == _savedZaiApi) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            key.isEmpty
                ? 'No Z.AI API key saved'
                : 'Z.AI API key already saved',
          ),
        ),
      );
      return;
    }
    await s.write(key: AppSettingsKeys.zaiApiKey, value: key);
    _savedZaiApi = key;
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key.isEmpty ? 'Z.AI API key removed' : 'Z.AI API key saved',
        ),
      ),
    );
  }
```

Change the unsaved banner condition from `_groqDirty` to `_zaiDirty`.

- [ ] **Step 3: Update the settings section copy**

Replace the GROQ AI section with:

```dart
            KeyedSubtree(
              key: _zaiSectionKey,
              child: EmSettingsSection(
              title: 'Z.AI',
              dirty: _zaiDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _zaiApiKey,
                    obscureText: _hideZaiApi,
                    decoration: InputDecoration(
                      labelText: 'Z.AI API Key',
                      suffixIcon: IconButton(
                        icon: Icon(_hideZaiApi ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hideZaiApi = !_hideZaiApi),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Free GLM-4.7-Flash API key at z.ai',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saveZaiApiKey,
                    child: const Text('Save API key'),
                  ),
                ],
              ),
            ),
            ),
```

- [ ] **Step 4: Confirm Settings has no live Groq API usage**

Search `flutter_app/lib/screens/settings_screen.dart` for `groq` / `Groq` / `GROQ`. Expected: no matches. `retiredGroqApiKey` may appear only as the delete target in `_load()`.

- [ ] **Step 5: Commit**

Skip unless the user asked to commit.

```bash
git add flutter_app/lib/screens/settings_screen.dart
git commit -m "$(cat <<'EOF'
Store the process explain key as a Z.AI credential in Settings.

EOF
)"
```

---

### Task 4: Docs

**Files:**
- Modify: `README.md`
- Modify: `AGENT_ONBOARDING.md`

**Interfaces:**
- Consumes: none
- Produces: Groq removed from user-facing and onboarding docs; Z.AI GLM-4.7-Flash documented as the Process AI explanation provider

- [ ] **Step 1: Replace Groq in README external integrations**

In `README.md`, replace:

```markdown
  - **Groq API** (Process AI explanation)
```

with:

```markdown
  - **Z.AI GLM-4.7-Flash** (Process AI explanation)
```

- [ ] **Step 2: Replace Groq in the AGENT_ONBOARDING mermaid diagram**

In `AGENT_ONBOARDING.md`, replace:

```mermaid
        Groq["Groq API (Process AI Explanation)"]
```

with:

```mermaid
        Zai["Z.AI GLM-4.7-Flash (Process AI Explanation)"]
```

and replace:

```mermaid
    UI -->|HTTPS| Groq
```

with:

```mermaid
    UI -->|HTTPS| Zai
```

- [ ] **Step 3: Commit**

Skip unless the user asked to commit.

```bash
git add README.md AGENT_ONBOARDING.md
git commit -m "$(cat <<'EOF'
Document Z.AI as the process AI explanation provider.

EOF
)"
```

---

### Task 5: Verify

**Files:** none new

- [ ] **Step 1: Run contract tests**

From `flutter_app/`:

```bash
flutter test test/process_ai_explain_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 2: Analyze changed Dart files**

From `flutter_app/`:

```bash
flutter analyze lib/services/process_ai_explain.dart lib/screens/process_detail_screen.dart lib/screens/settings_screen.dart lib/settings/app_settings_keys.dart
```

Expected: no issues in those files.

- [ ] **Step 3: Confirm Groq is gone from app code and top-level docs**

From repo root:

```bash
rg -n -i "groq" flutter_app/lib README.md AGENT_ONBOARDING.md
```

Expected matches: only `AppSettingsKeys.retiredGroqApiKey = 'groq_api_key'` (the delete-on-load leftover key). No Groq API URL, no Groq Settings copy, no Groq mermaid node.

Manual check after implementation (user device): paste a Z.AI key in Settings → Z.AI, open a process, tap Explain Process, confirm a JSON verdict renders and the footer says `Powered by Z.AI · glm-4.7-flash`.

---

## Spec coverage

| Spec item | Task |
| --- | --- |
| Endpoint `https://api.z.ai/api/paas/v4/chat/completions` | Task 1 |
| Model `glm-4.7-flash` | Task 1 |
| Bearer auth + `Accept-Language: en-US,en` | Task 1 |
| `thinking.type = disabled` | Task 1 |
| `temperature: 0.2`, `max_tokens: 1024`, JSON mode | Task 1 |
| Do not set `do_sample: false` | Task 1 test asserts `containsKey('do_sample')` is false |
| 20s timeouts | Task 2 (keep existing Dio timeouts) |
| New `zai_api_key`; do not migrate Groq key | Task 2 + Task 3 |
| Delete leftover `groq_api_key` | Task 3 |
| Settings title `Z.AI`, deep link `?section=zai` | Task 2 CTA + Task 3 |
| Signup copy points at `z.ai` | Task 3 |
| Rename Groq helpers/flags and attribution copy | Task 2 |
| README + AGENT_ONBOARDING | Task 4 |
| No fallback, streaming, schema, or layout change | Tasks 2–3 leave prompt/UI/cache unchanged |
