# Program Summary - Endpoint Monitor

**Date:** 2026-10-09  
**Repository:** `endpoint-monitor`  
**Product:** Self-hosted Endpoint Detection, Response (EDR), and digital forensics platform

This document is a full-project snapshot for humans and agents: what the system is, how it is built, what it can do, and where the code lives. Day-to-day product docs remain in [`README.md`](README.md); agent working instructions are in [`AGENTS.md`](AGENTS.md).

---

## 1. Executive summary

**Endpoint Monitor** lets a security analyst or admin monitor and remotely control a Windows PC from a phone, without a third-party cloud control plane. An elevated **.NET 10 Windows agent** runs on the host; a **Flutter** mobile app connects over LAN or VPN (e.g. Tailscale) using REST for pairing/export and a WebSocket for live telemetry and commands.

The platform covers:

- Real-time process, network, and system telemetry
- Sysmon event ingestion and forensic export
- Active response: kill/suspend processes, firewall blocks, full host isolation
- Threat intel highlighting, VirusTotal reputation, optional AI process explanation
- Browser history, installed software inventory/uninstall, remote power/volume/screenshot controls
- Local WPF desktop console for pairing, devices, diagnostics, and settings

Approximate scale (source only, excluding `bin`/`obj`): ~69 C# files in the agent, ~84 Dart files under `flutter_app/lib`, plus dedicated test projects for both stacks.

---

## 2. Problem & design goals

| Goal | How it is addressed |
|------|---------------------|
| No cloud dependency | Peer-to-peer agent ↔ phone over LAN/VPN |
| Untrusted local networks | Short-lived pairing PIN → opaque device token; peppered hash at rest; Bearer auth on `/ws` |
| Fast SOC visibility | ~1s-class WebSocket telemetry (intervals configurable under `Monitoring`) |
| Meaningful containment | Process suspend/kill, IP/port/process firewall rules, machine isolation with watchdog |
| Forensics | Sysmon XML → SQLite timeline; export JSON/CSV; browser history; audit log |
| Operability | Desktop Pair UI, health endpoint, Windows Service autorun, single-exe publish path |

---

## 3. System architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter mobile app (Android / iOS; other Flutter targets)  │
│  Bloc/Cubit · go_router · Dio · WebSocket · secure storage  │
└───────────────────────────┬─────────────────────────────────┘
                            │  REST (pairing, devices, export)
                            │  WebSocket /ws (telemetry + commands)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Windows agent (Kestrel ASP.NET Core Minimal APIs)          │
│  · PairingAuthService / AuthTokenValidator                  │
│  · ResponseCommandService (EDR orchestrator)                │
│  · Collectors + HostedServices (broadcast, Sysmon, intel…)  │
│  · SQLite (endpoint_monitor.db under %LocalAppData%)        │
│  · WPF Desktop console (loopback /local/* APIs)             │
└───────────────────────────┬─────────────────────────────────┘
                            │  Win32 / WMI / Registry / netsh /
                            │  Event Log / Sysmon
                            ▼
                     Windows OS subsystems
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
         VirusTotal    Threat feeds    Z.AI (client)
         (agent)       (agent)         (process explain)
```

**Data plane:** Agent pushes telemetry and alerts over WebSocket; client pulls/commands via JSON message `type` fields handled by `ResponseCommandService`.

**Control plane (local only):** Desktop console talks to loopback `/local/*` endpoints for pairing codes and device management without exposing those to the network.

---

## 4. Major components

### 4.1 Windows agent (`windows_service/`)

| Area | Role |
|------|------|
| `Program.cs` | Composition root: DI, Kestrel bind, middleware (security headers, rate limit, optional IP allowlist), REST + `/ws` |
| `Desktop/` | WPF setup shell: Home, Pair, Devices, Diagnostics, Settings; tray; optional “start with Windows” service registration |
| `LocalConsoleApi.cs` | Loopback-only JSON for the desktop UI |
| `Collectors/` | Process, network, throughput, installed software, system info |
| `Hosted/` | Broadcast loop, system info, Sysmon watcher, firewall block expiry, isolation watchdog, threat intel refresh |
| `Services/` | Pairing, token validation, WebSocket manager, firewall isolation, VT, threat intel, GeoIP, netsh runner |
| `Commands/ResponseCommandService.cs` | All privileged remote actions |
| `Database/` | SQLite schema + queries (parameterized / ORM) |
| `Sysmon/` | Installer, hardened config XML, parser, ingest |
| `Browser/` | Multi-profile browser history reader (SQLite) |
| `Alerts/AlertEngine.cs` | Rule evaluation on Sysmon events → WS `alert` broadcasts |
| `Endpoints/` | HTTP registration helpers (as present) |

**Binary / SCM:** `EndpointMonitorService.exe`, Windows service name **`EndpointMonitor`**. Runs elevated (`LocalSystem` when installed as a service) for WMI, firewall, Sysmon, and process APIs.

**Default ports:** HTTP `5000`, optional HTTPS `5001` (`Server` section in `appsettings`).

### 4.2 Flutter client (`flutter_app/`)

| Area | Role |
|------|------|
| `main.dart` / `app.dart` | Entry, Bloc providers |
| `app_router.dart` | `go_router` + shell nav; redirect when disconnected |
| `connect/` + connect screens | Wi-Fi vs Tailscale guided pairing; QR scan path |
| `bloc/` | Connection, process, network, events, firewall, controls, alerts, browser, software, threat intel, watchlist, system info |
| `screens/` | Dashboard, processes/detail, network/detail, events, firewall, controls, alerts, browser, software, watchlist, settings, feedback, paired devices, more |
| `services/` | Alert notifications, Z.AI process explain client |
| `task/` | Foreground/background task to keep WebSocket alive when minimized |
| `settings/` | Non-secret prefs; secrets in `flutter_secure_storage` (`em_host`, `em_token`) |

**Package / IDs:** `endpoint_monitor` · Android `com.endpointmonitor.endpoint_monitor` · iOS/macOS `com.endpointmonitor.endpointMonitor` · Dart SDK `^3.7`.

### 4.3 Desktop console (part of agent)

Local WPF app used on the monitored PC to:

- Show health / addresses
- Generate pairing PIN / QR payload
- List and revoke paired devices
- Diagnostics and agent settings (including Windows Service autorun)

It must not be confused with the Flutter “dashboard”; it is the on-host operator UI.

### 4.4 Supporting trees

| Path | Purpose |
|------|---------|
| `windows_service.Tests/` | xUnit tests (isolation, pairing QR, local API, Sysmon config resource, UI settings, etc.) |
| `flutter_app/test/` | Widget/unit tests (connect flow, blocs, pairing QR, feedback, network UI, …) |
| `flutter_design/` | Design references (cyber slate console, screens) |
| `docs/superpowers/` | Specs/plans for past feature work |
| `screenshots/` | README showcase images |
| `tools/` | Ancillary tools (e.g. NetworkTestProbe) |
| `secure-coding-standing-instructions.md` | Security standing rules (also `.cursor/rules/secure-coding.mdc`) |
| `AGENTS.md` | Instructions for coding agents |

---

## 5. Feature inventory

### 5.1 Connectivity & auth

- Guided connect: **This Wi-Fi** vs **Away from home (Tailscale)**
- Pairing: 6-digit code from desktop Pair screen → `POST /api/auth/pairing/complete` → device token (returned once)
- Token storage: client secure storage; server stores SHA-256(token + `Auth:DeviceTokenPepper`)
- WebSocket session: `Authorization: Bearer <token>` on `/ws`
- Device list/revoke via authenticated API and/or loopback desktop API
- Optional IP allowlist (`AllowedIpAddresses`), AspNetCoreRateLimit on pairing/API/export
- Security headers on HTTP responses (nosniff, DENY frame, CSP, referrer policy)

### 5.2 Live monitoring

- Process inventory with parent/child, path, CPU/RAM-style metrics
- Network connections with threat-intel highlighting and GeoIP (MaxMind GeoLite2 DBs shipped/placed beside the agent)
- Dashboard: host health, resource/socket visibility, system info
- Configurable broadcast/cache intervals (`Monitoring` in appsettings; example uses active broadcast every 5s when configured that way-product docs often describe a ~1s loop; treat config as source of truth)

### 5.3 Detection & forensics

- **Sysmon:** auto-install/configure; ingest Event IDs including process create (1), network (3), DNS (22); store in `SysmonEvents`; export via `/export/events`
- **AlertEngine:** e.g. connection to bad IP, browser on non-HTTP ports, flagged process start, encoded PowerShell command lines
- **Watchlist / flag process:** persist flagged names; alert on start
- **Browser history:** read from common Chromium/Firefox-style profiles
- **Installed software:** inventory; optional new-install monitoring; remote uninstall command
- **AuditLog:** server-side trail for sensitive actions

### 5.4 Active response (EDR)

| Capability | Mechanism (summary) |
|------------|---------------------|
| Kill process tree | `Process.Kill` (tree); protected critical process names blocked |
| Suspend / resume | `NtSuspendProcess` / `NtResumeProcess` via P/Invoke |
| Block / unblock IP | `netsh advfirewall` rules (`EM_BLOCK_*`); optional expiry |
| Block outbound port | Dedicated outbound TCP port block rules |
| Block / unblock process network | Resolve exe path (WMI); program-scoped firewall rules |
| Isolate / unisolate host | Default-deny firewall profiles + allow rules for agent ports; SQLite `IsolationState`; **~90s watchdog** if no authenticated WS client; rollback on failed verify |
| Screenshot | Desktop capture → base64 PNG over command result |
| Power / session | Lock, logoff, restart, shutdown, cancel shutdown, sleep, display off |
| Audio | Set volume, toggle mute |
| Reputation | VirusTotal file hash lookup (`check_reputation`) |
| Threat intel | Status/entries/refresh against cached bad-IP feeds |

### 5.5 Analyst UX extras

- AI process explanation via **Z.AI GLM** (client-side HTTPS; not the agent control plane)
- Feedback form (Formspree client in Flutter tests/services)
- PIN unlock gate widget for sensitive UI (as implemented in widgets)
- Local notifications for alerts

---

## 6. Security model (condensed)

1. **Pairing is the trust bootstrap** - physical/desktop access produces a short-lived PIN; network alone cannot mint tokens without it (rate-limited).
2. **Tokens are opaque; hashes are stored** - pepper in `appsettings.json` must be long and secret; never commit real peppers/keys.
3. **Authorize on the agent** - every WS command and privileged REST path re-validates the device token; UI is not a security boundary.
4. **Fail closed** - invalid input, auth failure, or command errors deny; details stay in server logs.
5. **Injection hardening** - IP/process name validation before `netsh`; parameterized SQLite; protected process denylist for kill/suspend.
6. **Isolation safety** - verify + rollback; watchdog auto-unisolate; documented emergency `netsh` recovery in README when the phone cannot reach the agent.
7. **Secrets placement** - VT API key and pepper in agent config; Flutter secrets in platform secure storage; do not put tokens in `SharedPreferences`.

Standing checklist: `secure-coding-standing-instructions.md`.

---

## 7. Data model (SQLite)

Database file: `%LocalAppData%\EndpointMonitor\endpoint_monitor.db`

| Table | Purpose |
|-------|---------|
| `SysmonEvents` | Normalized Sysmon timeline |
| `DeviceAuthTokens` | Peppered token hashes, device name, timestamps, revoke state |
| `FirewallBlocks` | IP/port blocks + expiry metadata |
| `FirewallProcessBlocks` | Executable path network blocks |
| `IsolationState` | Host isolation flag + saved restore policies |
| `BadIpList` | Threat intel cache |
| `FlaggedProcesses` | Watchlist names |
| `AlertAck` | Acknowledged alerts |
| `InstalledSoftwareState` | Software monitoring baseline/state |
| `AuditLog` | Action audit trail |

---

## 8. APIs & WebSocket command catalog

### 8.1 REST

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `GET /health` | None | Liveness / version-style status |
| `GET /local/status` | Loopback | Desktop console health |
| `GET /local/pairing` | Loopback | Current pairing code payload |
| `GET /local/devices` | Loopback | Paired devices (no hashes) |
| `POST /local/devices/revoke` | Loopback | Revoke by id |
| `POST /api/auth/pairing/complete` | Pairing code | Issue device token |
| `GET /api/auth/devices` | Bearer | List devices |
| `POST /api/auth/devices/revoke` | Bearer | Revoke device |
| `GET /export/events` | Bearer | Sysmon export (`from`/`to`/`format`) |
| `GET/POST … /ws` (mapped `/ws`) | Bearer | Telemetry + commands |

### 8.2 WebSocket command `type` values

Implemented in `ResponseCommandService.HandleAsync`:

**Process / watchlist:** `kill_process`, `suspend_process`, `resume_process`, `flag_process`, `unflag_process`, `get_flagged_processes`  
**Firewall / isolation:** `block_ip`, `unblock_ip`, `block_outbound_port`, `block_process`, `unblock_process`, `isolate_machine`, `unisolate_machine`, `get_firewall_snapshot`  
**Intel / reputation:** `check_reputation`, `get_threat_intel_status`, `get_threat_intel_entries`, `refresh_threat_intel`  
**Forensics / inventory:** `get_recent_events`, `get_browser_history`, `get_installed_software`, `uninstall_software`, `ack_alert`, `get_system_info`  
**Host controls:** `lock_screen`, `logoff_user`, `restart_machine`, `shutdown_machine`, `sleep_machine`, `cancel_shutdown`, `turn_off_display`, `set_volume`, `toggle_mute`, `capture_desktop_screenshot`

Telemetry/alert pushes use separate message types (e.g. `telemetry`, `alert`) from hosted services / `AlertEngine`, not the command switch above.

---

## 9. Tech stack

| Layer | Technologies |
|-------|----------------|
| Mobile | Flutter, Dart ^3.7, flutter_bloc, go_router, Dio, web_socket_channel, flutter_secure_storage, flutter_foreground_task, mobile_scanner, … |
| Agent | .NET 10 (`net10.0-windows`), ASP.NET Core Minimal APIs / Kestrel, Windows Service, WPF desktop UI |
| Persistence | SQLite via sqlite-net-style entities in `AppDatabase` |
| OS | Win32 P/Invoke, WMI, Registry, Windows Firewall (`netsh`), Windows Event Log / Sysmon |
| Hardening | AspNetCoreRateLimit, security headers, optional IP allowlist |
| External | VirusTotal API v3, Abuse.ch Feodo + Emerging Threats IP feeds, MaxMind GeoLite2, Z.AI GLM (client) |

---

## 10. Repository layout (top level)

```
endpoint-monitor/
├── AGENTS.md                          # Agent instructions
├── README.md                          # Human product + quick start + playbooks
├── Program Summary[2026-10-09].md     # This document
├── secure-coding-standing-instructions.md
├── flutter_app/                       # Mobile client
├── windows_service/                   # Agent + desktop console
├── windows_service.Tests/             # Agent tests
├── flutter_design/                    # UI design artifacts
├── docs/superpowers/                  # Historical specs/plans
├── screenshots/                       # Marketing/UI shots
├── tools/                             # Helper projects
└── .cursor/rules/                     # Cursor always-apply rules (secure coding)
```

---

## 11. Configuration & operations

### 11.1 Agent config (`appsettings.example.json` → `appsettings.json`)

Notable sections:

- **Auth:** `DeviceTokenPepper` (required, ≥32 random chars), optional `JwtSigningKey`
- **Server:** `Port`, `UseHttps`, `HttpsPort`
- **IpRateLimiting:** pairing/API/export limits
- **AllowedIpAddresses:** empty = allow all (plus other middleware); non-empty = whitelist
- **VirusTotal:** API key + cache TTL
- **ThreatIntel:** enable, interval, feed URLs, entry TTL
- **SoftwareMonitoring:** install-check interval / alert caps
- **Monitoring:** broadcast/idle/system-info/cache intervals

Never commit real secrets in `appsettings.json`.

### 11.2 Run (dev)

```bash
# Agent (elevated)
cd windows_service
copy appsettings.example.json appsettings.json   # then set pepper
dotnet run

# Flutter
cd flutter_app
flutter pub get
flutter run
```

Health check: `GET http://localhost:<port>/health`.

Publish notes: `windows_service/BUILD-SINGLE-EXE.md`, `windows_service/RUN.txt`.

### 11.3 Isolation emergency recovery

If isolate leaves the phone unable to reach the agent, use elevated local `netsh` cleanup (full command list in [`README.md`](README.md)), then reconnect and **Unisolate Machine** so SQLite matches the live firewall. Watchdog should auto-restore within ~90s if no authenticated client remains connected.

---

## 12. Testing

| Suite | Command |
|-------|---------|
| Agent | `dotnet test windows_service.Tests/EndpointMonitorService.Tests.csproj` |
| Flutter | `cd flutter_app && flutter test` |
| Flutter analyze | `cd flutter_app && dart analyze` |

Agent tests emphasize isolation helpers, local console API, pairing QR payloads, network helpers, Sysmon embedded config, and desktop UI settings stores. Flutter tests cover connect/pairing flows, selected blocs, and UI pieces.

---

## 13. Typical analyst workflows

1. **Ransomware-style containment:** identify process → suspend → isolate host → investigate while frozen → remediates/kill as needed.  
2. **Suspicious outbound IP:** Network screen (red threat match) → process detail → VT / AI explain → block IP or kill process.  
3. **Timeline review:** Events (Sysmon) → filter/export → correlate with alerts and watchlist flags.

Detailed playbooks: [`README.md`](README.md).

---

## 14. Known product boundaries

- **Windows-only agent** - monitoring target is a Windows host; the Flutter client is cross-platform but the EDR surface is Windows-centric.
- **No central multi-tenant cloud** - one agent instance per monitored machine; scale-out is “install more agents,” not a shared SaaS backend.
- **VPN for remote access** - Tailscale (or similar) is the documented away-from-home path; the product does not itself provide a relay.
- **High privilege by design** - containment features require admin/service rights; misuse or bugs can disrupt network/process state (hence watchdog + recovery docs).
- **Third-party key dependency** - VT and Z.AI features need configured API access; threat feeds need outbound HTTPS from the agent.

---

## 15. Documentation map

| Document | Audience |
|----------|----------|
| [`README.md`](README.md) | Humans: features, screenshots, quick start, playbooks, API tables, isolation recovery |
| [`AGENTS.md`](AGENTS.md) | Coding agents: map, commands, conventions, security do/don’t |
| [`secure-coding-standing-instructions.md`](secure-coding-standing-instructions.md) | Security baseline for all contributors/agents |
| `windows_service/RUN.txt` / `BUILD-SINGLE-EXE.md` | Agent run/publish |
| `docs/superpowers/**` | Historical design/plan records |
| This file | Dated comprehensive program summary |

---

## 16. Summary statement

Endpoint Monitor is a **self-hosted, zero-cloud-control-plane EDR stack**: a privileged Windows agent exposes hardened local APIs and a command WebSocket; a Flutter app provides SOC-style visibility and remote response. Strengths are pairing-based trust, real-time telemetry, Sysmon-backed forensics, and strong containment primitives (especially isolation with safety nets). The codebase is split cleanly between `windows_service` (collection, auth, OS actions) and `flutter_app` (UX and client-side integrations), with shared security expectations documented for both humans and agents.
