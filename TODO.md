# Endpoint Monitor — follow-up work

Items identified after the initial implementation pass; not blocking basic dev/testing.

## Flutter — UX and protocol

- [ ] Handle inbound **`command_result`** (and related server acks) from the foreground task: parse in a bloc or bridge, show **SnackBars** for success/failure after kill/block/flag/etc.
- [ ] Prefer **named routes only** (Addendum A): replace `context.push('/processes/${pid}')` with `pushNamed('processDetail', pathParameters: {'pid': '$pid'})` (or equivalent) everywhere.
- [ ] **Ping/pong verification** on first connect: optionally assert first `pong` before showing Connected (aligns with Phase 0 acceptance text).
- [ ] **Browser history:** wire copy-to-clipboard (and optional favicon placeholder) where UI is still stubbed.
- [ ] **`dart_jsonwebtoken`:** either **use** it (e.g. decode JWT expiry for proactive re-auth) or **remove** the dependency to avoid drift from the plan.

## Windows service — alerts and telemetry

- [ ] **Phase 7 — new install detection:** add a rule (registry diff, Sysmon-driven heuristic, or scheduled lightweight check). Avoid heavy `Win32_Product` unless on-demand only.
- [ ] **Phase 9 — connection audit:** persist inbound connection attempts (IP, timestamp, success/fail) to SQLite or structured logs as in the plan.
- [ ] **TLS/WSS:** document and test full path: dev cert, `UseHttps: true`, Kestrel HTTPS endpoint, and Flutter client using **`wss://`** with cert trust (e.g. pinning or user-installed CA).

## Security and app hardening (Flutter)

- [ ] **401 / token expiry:** central handling when WebSocket or HTTP returns unauthorized (prompt re-auth, clear stale token).
- [ ] **App lock:** if required, enforce PIN/biometric on **cold start** and background return—not only store PIN in settings.

## Stretch goals (phases 10–11)

- [ ] **Multi-endpoint:** endpoint selector on home, credentials and blocs **scoped per endpoint** (not only “last 3” chips in connect/settings).
- [ ] **Export:** save/share exported event files on device (path_provider / share_plus) instead of dialog preview only.

## Process collector accuracy

- [ ] Revisit **per-process CPU %**: plan mentioned two samples with time delta; current implementation uses WMI formatted perf counters—validate against Task Manager under load.

## Environment (operators)

- [ ] Document **Sysmon** install (SwiftOnSecurity config) and **admin** requirement for the service in a short ops note if not already duplicated outside the dev plan.

---

*Last updated from implementation review; adjust priorities as you ship.*
