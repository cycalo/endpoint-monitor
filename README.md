# Endpoint Monitor

**Endpoint Monitor** pairs a **Flutter mobile client** with a **Windows endpoint agent** (ASP.NET Core hosted as a Windows Service). The agent collects Sysmon-driven telemetry, network and process data, firewall state, browser history, installed software, and threat-intel context; the phone connects over **WebSocket** (authenticated device tokens from pairing) for live views, alerts, and remote actions. The agent requires **elevated privileges** on Windows for WMI, Sysmon interaction, firewall rules, and process controls.

## Stack

| Area | Technology |
|------|------------|
| Mobile app | Flutter 3.x (Dart ^3.5), Material 3 |
| Mobile state / routing | `flutter_bloc`, `go_router` |
| Mobile persistence | `flutter_secure_storage` (host + device token), `shared_preferences` (UI/settings) |
| Mobile background | `flutter_foreground_task` + local notifications |
| Windows agent | .NET 10 (`net10.0-windows`), minimal APIs, Windows Service + optional tray UI (`UseWindowsForms`) |
| Agent DB | SQLite (`sqlite-net-pcl`) under `%LocalAppData%\EndpointMonitor\endpoint_monitor.db` |
| Agent HTTP | Kestrel; optional HTTPS ports via config |

## Features (what ships in-repo)

- **Pairing**: Short-lived pairing code from the Windows tray → opaque device token from `POST /api/auth/pairing/complete` (stored hashed server-side with `Auth:DeviceTokenPepper`, or legacy `Auth:JwtSigningKey` when pepper is empty — see `windows_service/Options/AuthOptions.cs`).
- **Live WebSocket command channel** (`/ws`): `Authorization: Bearer <device token>`; commands cover processes, network connections, firewall snapshots, browser history, installed software, timeline/threat-intel queries, system info, isolation/controls (exact names in `windows_service/Commands/ResponseCommandService.cs`).
- **Mobile UI**: Dashboard, processes (detail + watch hints), network (connection detail, threat highlighting), Sysmon-style events, “More” hub (browser history, software, alerts, firewall, controls, watchlist, settings); PIN unlock gate and theme switching.
- **Agent-side intelligence**: Optional **VirusTotal** lookups, **threat feed** ingestion (URLs configurable), **GeoIP** (optional `GeoLite2-City.mmdb`), **alert engine**, software-install monitoring, firewall block expiry jobs.
- **Exports**: Authenticated `GET /export/events` (JSON or CSV).
- **Developer helper**: `tools/NetworkTestProbe` — console harness for firewall/network testing scenarios.

## Architecture

```
endpoint-monitor/
├── flutter_app/          # Cross-platform Flutter client (package name: endpoint_monitor)
├── windows_service/      # EndpointMonitorService — HTTP + WebSocket + collectors + SQLite
├── tools/
│   └── NetworkTestProbe/ # Optional manual network/firewall probe
└── flutter_design/       # Static HTML mocks — not wired into the running app
```

**Layering**

- **Flutter**: `main.dart` → `app.dart` (Bloc providers, router) → `screens/` + `bloc/` + `widgets/`; WebSocket work runs in `task/` (foreground task handler).
- **Windows**: `Program.cs` wires DI, HTTP/WebSocket maps, and SQLite init; domain logic lives under `Collectors/`, `Commands/`, `Hosted/`, `Services/`, `Alerts/`, `Sysmon/`, `Database/`, `Models/`.

## Prerequisites

- **Flutter SDK** compatible with `flutter_app/pubspec.yaml` (Dart ^3.5).
- **.NET 10 SDK** (matches `windows_service/EndpointMonitorService.csproj`).

## Run — Windows agent

1. Copy `windows_service/appsettings.example.json` → `appsettings.json` (the real file is gitignored).
2. Set **`Auth:DeviceTokenPepper`** to a long random secret (32+ characters). If pepper is omitted, **`Auth:JwtSigningKey`** is used only as a **legacy pepper fallback** (same length rules) — not for JWT issuance in the current pairing flow.
3. Run **from an elevated shell** (Administrator):  
   `cd windows_service && dotnet run`
4. Default HTTP port: **`Server:Port`** (see example: `5000`). Optional HTTPS: `Server:UseHttps` / `Server:HttpsPort`.
5. Generate a pairing code from the **system tray** UI, then complete pairing in the mobile app.

Operational notes: `windows_service/RUN.txt`, publishing: `windows_service/BUILD-SINGLE-EXE.md`.

### Environment / secrets (placeholders only)

| Config | Purpose |
|--------|---------|
| `Auth:DeviceTokenPepper` | Peppers stored device-token hashes (primary) |
| `Auth:JwtSigningKey` | Legacy pepper if `DeviceTokenPepper` is empty |
| `VirusTotal:ApiKey` | Optional VT reputation calls |
| `AllowedIpAddresses` | Optional allowlist for `/ws` clients |
| User secrets | `UserSecretsId` in `.csproj` — optional local override |

Never commit real keys; keep `appsettings.json` local.

## Run — Flutter app

```bash
cd flutter_app
flutter pub get
flutter run
```

Use platform-specific run targets as usual (`-d windows`, `-d chrome`, device IDs, etc.). The app expects a reachable agent URL for HTTP (pairing, REST) and WebSocket — configure via the Connect / Settings flows (`em_host`, `em_token` in secure storage).

> **Note:** This repo’s `.gitignore` excludes `flutter_app/pubspec.lock`. Run `flutter pub get` after clone so versions resolve consistently.

## Test / lint

| Component | Command |
|-----------|---------|
| Flutter analyze | `cd flutter_app && flutter analyze` |
| Flutter tests | `cd flutter_app && flutter test` (currently a minimal placeholder test) |
| Windows agent build | `cd windows_service && dotnet build` |
| Network probe build | `cd tools/NetworkTestProbe && dotnet build` |

There is **no** automated test suite for the C# service in this repo. No GitHub Actions workflows were present at documentation time.

## Configuration / environments

- **Agent**: Single JSON config model (`appsettings.json` / env-specific variants such as `appsettings.Development.json` if present). Key sections: `Auth`, `Server`, `IpRateLimiting`, `AllowedIpAddresses`, `VirusTotal`, `ThreatIntel`, `SoftwareMonitoring`.
- **Threat intel**: Toggle `ThreatIntel:Enabled`; feed URLs under `ThreatIntel:Feeds`.
- **Software monitoring**: `SoftwareMonitoring:Enabled` and intervals.
- **Mobile**: Feature toggles and defaults mostly via `shared_preferences` keys in `flutter_app/lib/settings/app_settings_keys.dart`.

## Observability / analytics

No third-party analytics or APM SDKs are integrated in code reviewed for this doc. The agent uses standard **Microsoft.Extensions.Logging** (destination depends on hosting: console, Windows Event Log when run as a service, etc.). Mobile notifications are local (`flutter_local_notifications`) driven by app logic, not a remote analytics backend.

## Release / deployment

- **Agent**: See **`windows_service/BUILD-SINGLE-EXE.md`** for `dotnet publish` (self-contained single-file `EndpointMonitorService.exe`), service registration (`sc create EndpointMonitor`, tray helper), and Administrator/UAC behavior (`app.manifest`).
- **Mobile**: Standard Flutter store/build pipelines (`flutter build apk`, `flutter build ipa`, etc.); Android application id `com.endpointmonitor.endpoint_monitor`; iOS/macOS bundle id `com.endpointmonitor.endpointMonitor` (verify in Xcode / Gradle if you change signing).

## Contributing / docs index

- **[AGENT_ONBOARDING.md](./AGENT_ONBOARDING.md)** — Route map, paths, persistence, and conventions for assistants and new contributors.
- **`windows_service/RUN.txt`** — Short agent run checklist.
- **`windows_service/BUILD-SINGLE-EXE.md`** — Publish and Windows Service install.
