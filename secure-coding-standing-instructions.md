# Secure Coding — Standing Instructions

Drop this into whichever rules file your tool reads: `CLAUDE.md` (project root,
or `~/.claude/CLAUDE.md` for every project), `AGENTS.md`, `.cursorrules` /
`.cursor/rules/`, `.github/copilot-instructions.md`, or paste into a Claude.ai
Project's custom instructions. Keep the Core section everywhere. Include only
the stack addenda relevant to that repo — don't paste sections that don't
apply; irrelevant rules dilute the ones that matter.

---

## Core (always include)

1. Treat all external input — user input, API responses, file contents, query
   params, query results — as untrusted. Validate type, length, and format
   before use. Never build a query or command by string concatenation; use
   parameterized queries / prepared statements for any database access.

2. Encode or escape output for the context it lands in (HTML, SQL, shell,
   URL) before rendering or executing it.

3. Enforce authorization at every layer that touches data, not just the UI.
   If a feature restricts what a user can see or do, that restriction must be
   re-checked server-side or in the database (e.g. row-level security) —
   never assume a client-side check is sufficient, and never assume a user
   will only request data that's "theirs."

4. Never hardcode API keys, passwords, tokens, or secrets in code, comments,
   or example/test files. Use environment variables or a secrets manager. If
   a secret has to live somewhere insecure for the task to work, say so
   explicitly instead of quietly doing it.

5. Fail closed: on error, deny/reject by default rather than letting things
   through.

6. Every call to an external dependency (database, payment processor,
   third-party API, filesystem, network) needs a timeout, error handling, and
   a defined behavior on failure. No silent failures, no unhandled
   rejections, no hangs.

7. User-facing error messages stay generic. Full detail (stack traces,
   internal paths, query text) goes to server-side logs only — and logs must
   never contain secrets, passwords, or full PII.

8. Use current, non-deprecated crypto and hashing (bcrypt/argon2 for
   passwords, not MD5/SHA1; TLS, not plaintext). Default to secure config:
   HTTPS, least-privilege permissions, restrictive CORS, security headers
   (CSP, X-Frame-Options) on anything web-facing.

9. Before adding a dependency: confirm the package name actually exists
   (don't trust a confident-sounding suggestion at face value), prefer
   well-maintained/popular libraries over obscure ones, and pin a version
   rather than "latest."

10. Mark any placeholder, stub, or code you're not fully confident is secure
    with an explicit comment — don't let it pass as finished.

11. **Before presenting code that touches auth, payments, user data, or
    file/network/process operations, stop and re-read your own output.**
    Check specifically: what does unexpected input do here, what could an
    unauthenticated or wrong-role user do here, and what happens if a
    dependency this calls fails mid-operation. Fix what you find before
    calling it done.

---

## Stack addenda (include what's relevant)

### Supabase / Postgres
- Every table holding user data needs Row Level Security enabled, with a
  policy restricting reads/writes to the owning user or appropriate role.
  Never rely on the client only requesting "its own" data.
- Don't disable RLS "temporarily" to debug — debug locally with a
  service-role key instead.
- The anon/public key is public by design; the service-role key gets the
  same handling as a root password.

### Flutter / Dart
- Tokens and credentials go in `flutter_secure_storage` or the platform
  Keychain/Keystore — never `SharedPreferences` or plain files.
- Validate and sanitize anything arriving via deep links, intents, or
  platform channels before acting on it.

### Python
- Never `eval`/`exec` on input you don't fully control.
- `subprocess` calls use `shell=False` with an argument list, never a
  `shell=True` string built from input.

### Web / JS / TS
- Parameterized queries or ORM parameter binding for all DB access — same
  rule as everywhere else, called out because raw template strings are easy
  to reach for here.
- Session cookies: `HttpOnly`, `Secure`, `SameSite`.
- CSP and standard security headers on all responses.

### CI/CD
- Secrets live in the platform's secret store (GitHub Actions secrets,
  etc.), never in workflow YAML.
- Pin third-party Actions and dependencies to a commit SHA, not a floating
  tag like `latest` or `main`.

---

## Pre-ship checklist
Ask this of any feature before it ships — of the AI, and separately, of
yourself:

1. Has anyone tried to access this data or endpoint directly, not through
   the UI?
2. What happens when each external dependency this code calls fails or
   times out?
3. What happens on empty input, wrong-type input, and unexpectedly large
   input?

---

## Notes
- This is a floor, not a substitute for tooling. Pair it with a SAST scanner
  (Semgrep, Snyk), a secrets scanner (gitleaks) in pre-commit/CI, and — since
  you're already on Supabase — periodically run the project's security
  advisors to catch RLS and config drift a prompt alone won't catch.
- Research on prompting technique specifically found that telling the model
  to "act as a security expert" tends to perform *worse*, not better, than
  direct instructions like the ones above — so this file deliberately skips
  persona framing.
- Keep this file short. Past a certain instruction count, models don't
  selectively ignore the newest rules — they start ignoring all of them
  somewhat uniformly. Prune anything the model already does correctly
  without being told.
