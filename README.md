# Endpoint Monitor

Monitor and control a Windows PC from your phone. A **Flutter mobile app** connects to a **Windows agent** you run on the machine you want to watch — no cloud service required.

The agent collects process and network activity, Sysmon events, firewall state, browser history, and installed software. The app streams live data over WebSocket and supports alerts, threat-intel lookups, and remote response actions (kill process, block IP, isolate machine, and more).

## Features

- **Dashboard** — endpoint health, activity heatmap, system identity
- **Processes** — live list, detail view, watchlist, kill/suspend/resume, optional AI explain (Groq)
- **Network** — active connections, threat highlighting, IP blocking
- **Events** — Sysmon-style timeline
- **More** — browser history, software inventory, alerts, firewall, endpoint controls, settings
- **Agent** — optional VirusTotal, threat feeds, GeoIP, software-install monitoring, event export

The Windows agent needs **Administrator** privileges for WMI, Sysmon, firewall, and process actions.

## Quick start

**1. Run the Windows agent** (elevated shell):

```bash
cd windows_service
# Copy appsettings.example.json → appsettings.json and set Auth:DeviceTokenPepper (32+ random chars)
dotnet run
```

**2. Pair your phone** — generate a code from the agent's system tray, then enter the agent URL and code in the app's Connect screen.

**3. Run the Flutter app:**

```bash
cd flutter_app
flutter pub get
flutter run
```

Default agent port is `5000` (`Server:Port` in `appsettings.json`). Optional HTTPS and other settings are in `appsettings.example.json`.

## Requirements

- Flutter SDK (Dart ^3.5)
- .NET 10 SDK
- Windows x64 for the agent

## Project structure

```
endpoint-monitor/
├── flutter_app/       # Mobile client
├── windows_service/   # Windows agent (HTTP + WebSocket + SQLite)
└── tools/             # Optional dev utilities
```

## Configuration

| Setting | Purpose |
|---------|---------|
| `Auth:DeviceTokenPepper` | Secret for pairing tokens (required) |
| `VirusTotal:ApiKey` | Optional reputation lookups |
| `ThreatIntel:Feeds` | Optional IP blocklist feeds |
| Groq API key | Enter in app Settings for process AI explain |

Do not commit `appsettings.json` or API keys. The agent stores paired device tokens as peppered hashes — raw tokens live only on the phone.

## Build

```bash
cd flutter_app && flutter analyze
cd windows_service && dotnet build
```

Mobile: `flutter build apk` / `flutter build ipa`. Agent: `dotnet publish` from `windows_service/` for a self-contained exe.
