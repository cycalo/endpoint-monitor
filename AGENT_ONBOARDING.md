# Agent Onboarding — Endpoint Monitor

Cold-start guide for AI assistants and engineers. This document provides a comprehensive architectural analysis and system design breakdown of the Endpoint Monitor project.

---

## 1. Executive Architecture Overview

Endpoint Monitor is a self-hosted, lightweight Endpoint Detection and Response (EDR) system. It consists of a **Flutter mobile application** (client) and an elevated **C# .NET 10 Windows Service** (agent) that communicate directly over local networks or VPNs via secure REST APIs and real-time WebSockets.

### System Architecture Diagram

```mermaid
graph TD
    subgraph Flutter_Mobile_App["Flutter Mobile App (Client)"]
        UI["UI Screens (Dashboard, Processes, Network, Events, Controls, More)"]
        Blocs["Blocs & Cubits (Connection, Process, Network, Events, Firewall, Controls)"]
        SecStorage["Secure Storage (em_host, em_token)"]
        WSClient["WebSocket Client (Telemetry Stream & Command Dispatch)"]
        DioClient["Dio HTTP Client (Pairing & Event Export)"]
    end

    subgraph Windows_Agent_Service["Windows Agent (Elevated Service)"]
        Kestrel["Kestrel Web Server (ASP.NET Core Minimal APIs)"]
        WSManager["WebSocket Connection Manager"]
        CmdService["Response Command Service (EDR Orchestrator)"]
        PairingService["Pairing & Auth Service"]
        
        subgraph Telemetry_Collectors["Telemetry Collectors"]
            ProcColl["Process Collector (WMI + Win32)"]
            NetColl["Network Collector (IPHlpApi)"]
            SysmonColl["Sysmon Ingest Service (EventLog XML)"]
            SoftColl["Software Collector (Registry/WMI)"]
            BrowserColl["Browser History Reader (SQLite)"]
            SysInfo["System Info Collector"]
        end

        subgraph Background_Workers["Hosted Services (Background Workers)"]
            BroadcastWorker["Monitor Broadcast Service (1s telemetry loop)"]
            SysmonWorker["Sysmon Hosted Service"]
            IntelWorker["Threat Intel Updater Service"]
            FirewallExpiry["Firewall Block Expiry Service"]
        end

        SQLite["Local SQLite Database (endpoint_monitor.db)"]
    end

    subgraph External_Integrations["External Security Services"]
        VT["VirusTotal API v3 (Reputation Lookups)"]
        Feeds["Threat Intel Feeds (Malicious IP Blocklists)"]
        Groq["Groq API (Process AI Explanation)"]
    end

    %% Client-Server Communication
    WSClient <-->|WebSocket /ws with Bearer Token| WSManager
    DioClient -->|REST /api/auth/pairing/complete| Kestrel
    DioClient -->|REST /export/events| Kestrel

    %% Internal Agent Wiring
    Kestrel --> PairingService
    Kestrel --> WSManager
    WSManager --> CmdService
    CmdService --> SQLite
    CmdService --> Telemetry_Collectors
    BroadcastWorker --> Telemetry_Collectors
    BroadcastWorker --> WSManager
    SysmonWorker --> SysmonColl
    SysmonColl --> SQLite
    IntelWorker --> SQLite
    FirewallExpiry --> CmdService

    %% OS Integrations
    Telemetry_Collectors -->|Win32 API / WMI / Registry| Windows_OS["Windows OS Kernel & Subsystems"]
    CmdService -->|Win32 P/Invoke: NtSuspendProcess| Windows_OS
    CmdService -->|Process.Kill (Tree)| Windows_OS
    CmdService -->|Netsh: Firewall Rules & Host Isolation| Windows_OS

    %% External Connections
    CmdService -->|HTTPS| VT
    IntelWorker -->|HTTPS| Feeds
    UI -->|HTTPS| Groq
```

---

## 2. Project Snapshot

| Item | Value |
|------|--------|
| **Product** | Endpoint Monitor — mobile dashboard + remote controls for a monitored Windows PC |
| **Flutter Package** | `endpoint_monitor` (`flutter_app/pubspec.yaml`) |
| **Android Application ID** | `com.endpointmonitor.endpoint_monitor` |
| **iOS / macOS Bundle ID** | `com.endpointmonitor.endpointMonitor` |
| **Windows Service Binary** | `EndpointMonitorService.exe` (SCM name: **`EndpointMonitor`**) |
| **Database** | SQLite (`endpoint_monitor.db` in `%LocalAppData%\EndpointMonitor\`) |

---

## 3. Deep-Dive: Security Architecture

Endpoint Monitor is designed to operate securely in untrusted network environments (e.g., local Wi-Fi, shared LANs) without relying on a centralized cloud control plane.

### 3.1 Pairing Protocol & Authentication Flow
1. **Pairing Code Generation**:
   - When the agent runs, a user can generate a temporary **Pairing Code** (6-digit PIN) from the system tray icon, or by visiting `http://localhost:5000/local/pair` (restricted to loopback requests only).
   - The code is stored in-memory with a short expiry (default: 5 minutes).
2. **Key Exchange & Pairing Completion**:
   - The mobile client sends a `POST /api/auth/pairing/complete` request containing the pairing code and its device name.
   - The agent validates the pairing code. Upon success, it generates a cryptographically secure random **Device Token** (opaque string).
   - The agent hashes this token using SHA-256 combined with a server-side secret pepper (`Auth:DeviceTokenPepper` from `appsettings.json`) and stores the hash, device name, and creation time in the `DeviceAuthTokens` SQLite table.
   - The raw token is returned to the mobile client *once* and stored securely in `flutter_secure_storage`.
3. **Session Establishment**:
   - To stream telemetry, the mobile client opens a WebSocket connection to `/ws`.
   - The client passes the raw token in the `Authorization: Bearer <token>` header.
   - The agent's `AuthTokenValidator` extracts the token, hashes it with the configured pepper, and queries the database to verify if a matching, non-revoked token exists.

### 3.2 Transport Security & Hardening
- **Kestrel Configuration**: Supports dual-binding (HTTP on port `5000` and HTTPS on port `5001` with local certificates).
- **Security Headers**: Every HTTP response is injected with strict security headers:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Referrer-Policy: no-referrer`
  - `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'`
- **IP Access Control**: Optional IP address whitelisting (`AllowedIpAddresses` in `appsettings.json`) blocks unauthorized clients at the middleware layer.
- **Rate Limiting**: Integrated `AspNetCoreRateLimit` prevents brute-force pairing attempts and API flooding.

---

## 4. Deep-Dive: Sysmon Ingestion Pipeline

System Monitor (Sysmon) is a Windows system service and device driver that logs detailed system activity to the Windows Event Log. Endpoint Monitor ingests these events in real-time to build a forensic timeline.

```
+------------------------+      +------------------------+      +-------------------------+
|   Windows Event Log    | ---> |  SysmonHostedService   | ---> |   SysmonIngestService   |
| (Microsoft-Windows-    |      | (Background polling/   |      |  (XML Parsing, Filter,  |
|  Sysmon/Operational)   |      |  EventLogWatcher)      |      |   Normalization)        |
+------------------------+      +------------------------+      +-------------------------+
                                                                             |
                                                                             v
+------------------------+      +------------------------+      +-------------------------+
|  Real-time Telemetry   | <--- |  Broadcast To Clients  | <--- |     SQLite Database     |
|   (WebSocket Stream)   |      |  (WebSocket /ws)       |      |    (SysmonEvents Table) |
+------------------------+      +------------------------+      +-------------------------+
```

### Ingestion Details:
- **Sysmon Installation**: The agent includes an automated installer (`SysmonInstaller`) that downloads and configures Sysmon with a security-hardened configuration file if not already present.
- **Event Polling**: `SysmonHostedService` monitors the `Microsoft-Windows-Sysmon/Operational` event channel.
- **Parsing & Normalization**: `SysmonEventParser` extracts raw XML event data into structured fields:
  - **Event ID 1**: Process Creation (CommandLine, ParentPid, ProcessName).
  - **Event ID 3**: Network Connection (RemoteAddress, RemotePort, Protocol).
  - **Event ID 22**: DNS Query (QueryName, QueryStatus).
- **Storage**: Normalized events are committed to the `SysmonEvents` SQLite table for historical querying and forensic export (`POST /export/events`).

---

## 5. Deep-Dive: EDR Active Response Controls

The agent implements powerful, low-level operating system controls to contain threats directly from the mobile app.

### 5.1 Host Network Isolation
- **Mechanism**: When a machine is isolated (`isolate_machine` command), the agent injects strict Windows Firewall rules using `netsh advfirewall`:
  - `EM_ISOLATE_BLOCK_IN`: Blocks all incoming network traffic.
  - `EM_ISOLATE_BLOCK_OUT`: Blocks all outgoing network traffic.
  - `EM_ISOLATE_ALLOW_MONITOR` / `EM_ISOLATE_ALLOW_MONITOR_OUT`: Explicitly allows TCP traffic on the agent's port (e.g., `5000`) so the mobile app maintains control of the isolated host.
- **Persistence**: The isolation state is recorded in the `IsolationState` SQLite table. On agent startup, `FirewallBlockExpiryHostedService` verifies and re-enforces isolation if the service was restarted.

### 5.2 Process Suspension & Resumption
- **Forensic Containment**: Instead of killing a suspicious process (which destroys volatile memory and prevents forensic analysis), analysts can suspend it.
- **Win32 P/Invoke**: The agent opens a process handle using `OpenProcess` with `PROCESS_SUSPEND_RESUME` access and calls the undocumented native API `NtSuspendProcess` in `ntdll.dll`.
- **Resumption**: Calling `NtResumeProcess` restores the process threads to their active execution state.

### 5.3 Firewall IP & Process Blocking
- **IP Blocking**: Injects inbound/outbound block rules for specific IPs (`EM_BLOCK_<IP>`).
- **Process Execution Blocking**: Blocks specific executables from accessing the network. The agent queries WMI (`Win32_Process`) to resolve the full executable path of a running process and applies a firewall rule restricting that specific binary path.
- **Temporal Expiry**: Blocks can be configured with an expiry (e.g., block IP for 2 hours). `FirewallBlockExpiryHostedService` polls the database every minute and automatically purges expired rules.

---

## 6. Codebase Map & Navigation

### 6.1 Windows Agent (`windows_service/`)

| Directory / File | Responsibility |
|------------------|----------------|
| `Program.cs` | Composition root, dependency injection, REST endpoint mapping, and middleware setup. |
| `Collectors/` | Telemetry collection: `ProcessCollector` (CPU, RAM, threads), `NetworkCollector` (IPHlpApi active connections), `SystemInfoCollector` (hardware specs). |
| `Hosted/` | Background workers: `MonitorBroadcastHostedService` (broadcasts live process/network states to WebSockets every 1s), `SysmonHostedService` (event log watcher). |
| `Services/` | Core business logic: `PairingAuthService` (security tokens), `VirusTotalReputationService` (hash scanning), `ThreatIntelUpdater` (malicious IP feed downloader). |
| `Commands/` | `ResponseCommandService.cs` — Orchestrates and executes all EDR response actions (Kill, Suspend, Isolate, Block, Screenshot, Power Controls). |
| `Database/` | `AppDatabase.cs` (SQLite connection and queries), `DbEntities.cs` (Table structures). |
| `Sysmon/` | `SysmonInstaller.cs` (automated setup), `SysmonEventParser.cs` (XML ingestion). |

### 6.2 Flutter App (`flutter_app/lib/`)

| Directory / File | Responsibility |
|------------------|----------------|
| `main.dart` | Application entry point. Initializes secure storage and settings. |
| `app_router.dart` | Central routing hub using `go_router`. Implements redirect guards (sends unauthenticated users to `/connect`). |
| `bloc/` | **State Management**: Consumes real-time WebSocket streams and manages UI state. Key blocs include `ConnectionBloc`, `ProcessBloc`, `NetworkBloc`, `EventsBloc`, `FirewallBloc`. |
| `screens/` | UI Routes: `dashboard_screen.dart` (health & heatmap), `process_detail_screen.dart` (forensics & actions), `network_screen.dart` (connections & threat highlights), `events_screen.dart` (timeline). |
| `task/` | `endpoint_monitor_task_handler.dart` — Background service handler that maintains the WebSocket connection when the app is minimized. |

---

## 7. Flutter State Management & Telemetry Flow

The Flutter client uses the **Bloc (Business Logic Component)** pattern to handle the high-frequency telemetry stream.

```
+-----------------------------------------------------------------------------------+
|                                  WebSocket Stream                                 |
|  {"type": "telemetry", "data": {"processes": [...], "network": [...]}}            |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                                  ConnectionBloc                                   |
|  - Establishes and maintains WebSocket connection.                                |
|  - Dispatches raw JSON payloads to feature-specific Blocs.                        |
+-----------------------------------------------------------------------------------+
                     |                                       |
                     v                                       v
+----------------------------------------+   +--------------------------------------+
|              ProcessBloc               |   |             NetworkBloc              |
|  - Parses process telemetry.           |   |  - Parses network connections.       |
|  - Emits `ProcessLoaded` state.        |   |  - Cross-references Threat Intel.    |
|  - Dispatches `kill_process` commands. |   |  - Emits `NetworkLoaded` state.      |
+----------------------------------------+   +--------------------------------------+
```

---

## 8. Run & Test (Copy/Paste Commands)

### 8.1 Prerequisites
- **Flutter SDK** (Dart ^3.5)
- **.NET 10 SDK**
- **Windows 10/11 x64** (Administrator privileges required to run the agent)

### 8.2 Execution

```bash
# 1. Run the Windows Agent (Elevated PowerShell / CMD)
cd windows_service
# Copy example configuration
copy appsettings.example.json appsettings.json
# Run the agent
dotnet run

# 2. Run the Flutter App
cd flutter_app
flutter pub get
flutter run
```

---

## 9. Developer Conventions

1. **Telemetry Frequency**: The telemetry broadcast runs on a 1-second interval. Ensure any new collector added is optimized and does not block the main thread.
2. **Database Access**: Always use parameterized queries or SQLite-net ORM bindings (`AppDatabase.cs`). Never concatenate raw SQL strings.
3. **Error Handling**: Follow the "Fail Closed" principle. If a security check or command execution fails, explicitly deny/reject the action and log the error server-side.
4. **Bloc Structure**: Keep event and state definitions in the same file as their respective Bloc to maintain clean modularity.
