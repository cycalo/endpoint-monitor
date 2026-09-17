# Z.AI GLM-4.7-Flash Process Explain Design

## Goal

Replace Groq (`llama-3.3-70b-versatile`) with Z.AI `glm-4.7-flash` for
Process AI Explain. Remove Groq completely. Keep the same Flutter UI, JSON
schema, cache, and prompt purpose.

## Provider

- Endpoint: `https://api.z.ai/api/paas/v4/chat/completions`
- Model: `glm-4.7-flash`
- Auth: `Authorization: Bearer <key>`
- Extra header: `Accept-Language: en-US,en`
- Thinking: `{ "type": "disabled" }` (GLM-4.7 thinking is on by default)
- JSON mode: `{ "type": "json_object" }`
- Timeout: keep 20s connect and receive

## Generation settings

The original Groq call used `temperature: 0.3` and `max_tokens: 800`.

| Parameter | Value | Why |
| --- | --- | --- |
| `temperature` | `0.2` | Z.AI allows `[0.0, 1.0]`; 4.7-series default is `1.0`, which is too random for a security JSON verdict. `0.2` is slightly below the proven Groq `0.3` and above a hard `0.0`/`0.1` floor that can make output brittle. |
| `max_tokens` | `1024` | This is a cap, not a target. Unused tokens are not billed, and GLM-4.7-Flash is free. The eight-field JSON is typically a few hundred tokens; `512` risks truncating valid JSON. Z.AI's own examples and core-parameter guidance use `1024` as the practical floor. |
| `thinking.type` | `disabled` | This is the real cost/latency control. Do not leave thinking on and try to starve it with a low `max_tokens`. |

Do not set `do_sample: false`. Keep sampling with low temperature.

## Storage and settings

- New FlutterSecureStorage key: `zai_api_key`
- Do not reuse or migrate `groq_api_key` (incompatible credentials)
- Delete the Groq key constant and stop reading/writing it
- Settings section title: `Z.AI`
- Deep link: `/settings?section=zai`
- Signup copy: point at `z.ai` / `docs.z.ai`, not Groq

## Code and copy

- Retarget the existing Dio call in `process_detail_screen.dart`
- Rename Groq-specific helpers/flags (`_parseProcessExplanationFromGroqContent`, `needsGroqApiKeySetup`)
- Update error strings, report footer, and Settings labels to `Z.AI · glm-4.7-flash`
- Update `README.md` and `AGENT_ONBOARDING.md` Groq references

## Out of scope

- Multi-provider fallback
- Streaming
- Changing the Explain Process JSON schema or UI layout
- Raising temperature toward Z.AI's default `1.0`
