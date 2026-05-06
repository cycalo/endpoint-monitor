# Agent onboarding — Endpoint Monitor

Cold-start guide for AI assistants and engineers. Prefer reading paths cited here over guessing behavior.

## Project snapshot

| Item | Value |
|------|--------|
| Product | Endpoint Monitor — mobile dashboard + remote controls for a monitored Windows PC |
| Flutter package | `endpoint_monitor` (`flutter_app/pubspec.yaml`) |
| Android applicationId | `com.endpointmonitor.endpoint_monitor` |
| iOS / macOS bundle ID | `com.endpointmonitor.endpointMonitor` |
| Windows service binary | `EndpointMonitorService` — publishes as `EndpointMonitorService.exe`; SCM name **`EndpointMonitor`** (see `BUILD-SINGLE-EXE.md`) |

**Core flows**: Tray pairing code → mobile completes `POST /api/auth/pairing/complete` → **opaque device token** stored as `em_token` → foreground task opens WebSocket to `/ws` with `Authorization: Bearer <token>` → `AuthTokenValidator` checks token via `PairingAuthService` (peppered hash in SQLite) → Blocs consume streamed command results for UI.

## Stack & tooling (tight)

- **Flutter** + **Bloc** + **go_router** + **secure storage** + **foreground task** + **dio** (HTTP).
- **.NET 10** minimal hosting, **SQLite**, **AspNetCoreRateLimit**, **MaxMind.GeoIP2** (optional DB file), **Sysmon** ingestion/install paths under `windows_service/Sysmon/`.

## Where to start

| Concern | Path |
|---------|------|
| Flutter entry | `flutter_app/lib/main.dart` → `app.dart` |
| Router hub | `flutter_app/lib/app_router.dart` (`createAppRouter`) |
| Connection / credentials | `flutter_app/lib/bloc/connection_bloc.dart`; keys `em_host`, `em_token` (secure storage) |
| Foreground WebSocket task | `flutter_app/lib/task/endpoint_monitor_task_handler.dart`, `task_entry.dart` |
| Windows composition root | `windows_service/Program.cs` |
| WebSocket + REST maps | Same file: `/ws`, `/api/auth/*`, `/export/events` |
| Command dispatch | `windows_service/Commands/ResponseCommandService.cs` |
| SQLite schema / tables | `windows_service/Database/DbEntities.cs`, `AppDatabase.cs` |

## Feature / module map (non-exhaustive)

**Flutter (`flutter_app/lib/`)**

- `bloc/` — Feature Blocs/Cubits (connection, processes, network, firewall, events, alerts, browser, software, threat intel, controls, …).
- `screens/` — UI routes (dashboard, processes, network, events, connect, settings, …).
- `widgets/` — Shared UI (PIN gate, branded app bar, cards).
- `models/ws_models.dart` — DTOs shared with UI.
- `services/alert_notification_service.dart` — Local notification init.
- `settings/app_settings_keys.dart` — `SharedPreferences` keys and defaults.
- `theme/` — Material themes + `ThemeCubit`.

**Windows (`windows_service/`)**

- `Collectors/` — Process, network, throughput, system info, installed software.
- `Hosted/` — Broadcast loop, Sysmon ingest, tray icon, firewall expiry, threat-intel refresh, software detection, etc.
- `Services/` — Pairing/JWT validation, GeoIP, VirusTotal, threat updater, WebSocket manager.
- `Alerts/` — Alert engine.
- `Browser/` — History reader.
- `Sysmon/` — Installer + ingest/parser.

**Non-runtime**: `flutter_design/*.html` — static design references only.

**Tools**: `tools/NetworkTestProbe/Program.cs` — CLI flags documented in-file (`--simple-block-test`, `--tcp-host`, …).

## Navigation / route map (Flutter)

Implemented in `app_router.dart`:

| Route | Notes |
|-------|--------|
| `/connect` | Initial when disconnected; pairing / host entry |
| Shell tabs | `/dashboard`, `/processes`, `/network`, `/events`, `/more` |
| `/processes/:pid` | Process detail; query `?ghost=1` for killed-process snapshot |
| `/processes?watch=` | Initial watch filter query param |
| `/network?threats=1` | Highlight threats |
| `/network/detail` | **Extra**: requires `NetworkConnection` in `state.extra` |
| `/events?hour=` | Focus hour (UTC string param) |
| `/browser`, `/software`, `/software/detail` | Software detail uses **extra** `InstalledSoftwareItem` |
| `/alerts` | Optional `?type=` filter |
| `/firewall`, `/controls`, `/watchlist`, `/settings` | Pushed from **More** |

**Redirect logic**: Disconnected users are sent to `/connect` or `/dashboard` depending on whether `em_host` allows reconnect — see `redirect` closure in `createAppRouter`.

**Transient overlays**: `pop_transient_overlay_routes.dart`, `auto_close_transient_routes_on_leave_mixin.dart` — bottom nav switches pop stacked overlays.

**WebSocket `type` strings** (client → agent; see `ResponseCommandService.HandleAsync`):  
`kill_process`, `block_ip`, `unblock_ip`, `isolate_machine`, `unisolate_machine`, `suspend_process`, `resume_process`, `flag_process`, `unflag_process`, `get_browser_history`, `get_installed_software`, `uninstall_software`, `get_recent_events`, `ack_alert`, `get_firewall_snapshot`, `get_flagged_processes`, `block_outbound_port`, `block_process`, `unblock_process`, `get_timeline`, `check_reputation`, `get_threat_intel_status`, `get_threat_intel_entries`, `get_system_info`, `refresh_threat_intel`, `lock_screen`, `logoff_user`, `restart_machine`, `shutdown_machine`, `sleep_machine`, `cancel_shutdown`, `turn_off_display`, `set_volume`, `toggle_mute`, `capture_desktop_screenshot`.  
Separately, `Program.cs` handles `ping` / `pong` on `/ws`.

## Data & persistence

**Mobile**

- **Secure storage**: `em_host`, `em_token` — pairing and WebSocket auth.
- **SharedPreferences**: Keys in `app_settings_keys.dart` (`em_http_base`, notification toggles, PIN lock, event defaults, UI prefs).
- **Foreground task**: Internal keys `ws_host`, `ws_token` (task handler) passed from main isolate.

**Windows**

- **SQLite file**: `%LocalAppData%\EndpointMonitor\endpoint_monitor.db`.
- **Tables** (from `DbEntities.cs`): `SysmonEvents`, `FlaggedProcesses`, `FirewallBlocks`, `FirewallProcessBlocks`, `AuditLog`, `IsolationState`, `BadIpList`, `AlertHistory`, `AlertAck`, `InstalledSoftwareState`, `DeviceAuthTokens`.

## Third-party / network (code-backed)

- **WebSocket + REST** to the agent (LAN/VPN — deployment-specific).
- **VirusTotal API v3** — when `VirusTotal:ApiKey` set (`Program.cs` HttpClient named `virustotal`).
- **Threat intel feeds** — HTTP downloads from URLs in `ThreatIntel:Feeds` (defaults in `appsettings.example.json`).
- **Optional GeoLite2** — `GeoLite2-City.mmdb` beside exe or project root (see `.csproj` `Content` item); requires MaxMind licensing separately.

No cloud control plane is implied by the repo; everything targets your self-hosted agent instance.

## Secrets

| Secret / material | Where loaded |
|-------------------|--------------|
| `DeviceTokenPepper` (and legacy `JwtSigningKey` pepper fallback) | `appsettings.json` / env / user secrets (`UserSecretsId` on project) |
| VirusTotal key | `VirusTotal:ApiKey` |
| Paired device tokens | Derived at pairing; hashed server-side; raw token only on mobile secure storage |

Never paste real secrets into issues or docs.

## Run & test (copy/paste)

```bash
# Flutter
cd flutter_app && flutter pub get && flutter analyze && flutter test && flutter run

# Agent (elevated Windows shell)
cd windows_service && dotnet run

# Optional probe
cd tools/NetworkTestProbe && dotnet run -- --help   # see Program.cs for flags
```

## Conventions for changes

- **Flutter**: Match existing **Bloc** patterns (`Events`/`States` in same file as bloc); use **go_router** for navigation; prefer **Equatable** for states already using it; keep platform-channel-free logic in Blocs where possible.
- **Windows**: **Singleton** services registered in `Program.cs`; **hosted services** for loops/timers; **SQLite** access through `AppDatabase`; JSON serialization via `AppJson.Options` where used today.
- **Naming**: Follow adjacent files (`EndpointMonitor*` / `em_*` keys).

## Hygiene & repo quirks

- **Gitignored**: `windows_service/appsettings.json`, `GeoLite2-City.mmdb`, build outputs (`bin/`, `obj/`, `build/`, `.dart_tool/`), `flutter_app/pubspec.lock` — do not commit secrets or generated artifacts; ensure teammates run `flutter pub get`.
- **Single agent instance per port** — only one listener on `Server:Port`.
- **Administrator elevation** required for full agent functionality (`RUN.txt`, `app.manifest`).
- **Scope PRs** per component (`flutter_app` vs `windows_service` vs `tools`) when practical.

## High-value reference files

| File | Why |
|------|-----|
| `windows_service/RUN.txt` | Agent quick start |
| `windows_service/BUILD-SINGLE-EXE.md` | Publish + service install |
| `windows_service/appsettings.example.json` | Full config surface |
| `flutter_app/lib/app_router.dart` | All routes and query params |
| `windows_service/Commands/ResponseCommandService.cs` | Command vocabulary |
| `windows_service/Database/DbEntities.cs` | Table names / columns |

No OpenAPI spec, ADRs, or CI workflow definitions were found in-repo at onboarding write time.

## Suggested first steps (new agent)

1. Read **`windows_service/RUN.txt`** and **`appsettings.example.json`**.
2. Open **`flutter_app/lib/app_router.dart`** and **`flutter_app/lib/app.dart`** for navigation and state wiring.
3. Open **`windows_service/Program.cs`** for endpoints and DI.
4. Run **`flutter analyze`** and **`dotnet build`** on `windows_service` to verify the workspace.
