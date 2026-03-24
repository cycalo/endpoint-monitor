# Endpoint Monitor — Comprehensive Development Plan
> For use with Cursor AI agents across both projects in the monorepo

---

## Project Overview

A Flutter mobile app that remotely monitors and responds to a Windows PC endpoint.
The system consists of two tightly coupled applications built and iterated together,
feature by feature.

**Monorepo structure:**
```
endpoint-monitor/
├── flutter_app/        # Flutter/Dart — Android mobile client
├── windows_service/    # C# .NET 10 — Windows background service
└── DEVELOPMENT_PLAN.md
```

---

## Tech Stack (Confirmed)

### Windows Service
- **.NET 10 Worker Service** — background service host
- **ASP.NET Core** — HTTP + WebSocket/SignalR transport layer
- **System.Management** — WMI for live process and network data
- **System.Diagnostics.Eventing.Reader** — Sysmon Event Log consumer
- **Microsoft.Data.Sqlite** — browser history reading + local DB
- **SQLite-net-pcl** — ORM for local event history database
- **netsh advfirewall** — firewall rule management via Process.Start

### Flutter App
- **web_socket_channel** — WebSocket client
- **dio** — HTTP requests
- **flutter_secure_storage** — secure token persistence
- **dart_jsonwebtoken** — JWT handling
- **flutter_bloc** — state management
- **flutter_local_notifications** — push alerts
- **fl_chart** — charts for system overview

### Auth & Transport
- Static secret token (testing phase) → JWT with expiry (production)
- WSS (WebSocket Secure) in production
- Every request presents Bearer token or connection is rejected

---

## Prerequisites (Before Writing Any Code)

### 1. Install Sysmon on the Windows machine
```
# Download from Microsoft Sysinternals
# Run as Administrator:
Sysmon64.exe -accepteula -i sysmonconfig.xml
```
Use the SwiftOnSecurity Sysmon config from:
https://github.com/SwiftOnSecurity/sysmon-config

### 2. Verify Sysmon is logging
Open Event Viewer → Applications and Services Logs
→ Microsoft → Windows → Sysmon → Operational
You should see Event ID 1 entries (process creation).

### 3. Windows Service must run as Administrator
All data collection and response actions require elevated privileges.
Configure this in the service installer and during development.

---

## Data Models (Shared Contract)

Define these in both projects. The Windows service serialises to JSON,
Flutter deserialises from JSON. Keep field names identical.

```
ProcessInfo {
  pid: int
  name: string
  commandLine: string
  parentPid: int
  cpuPercent: double
  memoryMb: double
  startTime: string (ISO 8601)
  status: string
}

NetworkConnection {
  pid: int
  processName: string
  localAddress: string
  localPort: int
  remoteAddress: string
  remotePort: int
  protocol: string   // TCP or UDP
  state: string
}

SysmonEvent {
  eventId: int
  timestamp: string (ISO 8601)
  type: string        // ProcessCreate, NetworkConnect, ProcessTerminate, DnsQuery
  pid: int
  processName: string
  commandLine: string   // nullable
  parentPid: int        // nullable
  remoteAddress: string // nullable
  remotePort: int       // nullable
  dnsQuery: string      // nullable
  rawXml: string
}

BrowserHistoryEntry {
  browser: string     // chrome, edge, firefox
  url: string
  title: string
  visitTime: string (ISO 8601)
  visitCount: int
}

SystemInfo {
  cpuPercent: double
  ramUsedGb: double
  ramTotalGb: double
  diskUsedGb: double
  diskTotalGb: double
  uptime: string
  osVersion: string
  patchLevel: string
  loggedInUsers: List<string>
}

Alert {
  id: string
  timestamp: string
  severity: string   // low, medium, high
  type: string       // new_process, suspicious_connection, new_install, flagged_process
  message: string
  relatedPid: int    // nullable
}
```

---

## WebSocket Message Protocol

All messages are JSON. Every message has a `type` field.

### Service → Flutter (outbound streams)
```json
{ "type": "processes",        "data": [ ...ProcessInfo ] }
{ "type": "network",          "data": [ ...NetworkConnection ] }
{ "type": "sysmon_event",     "data": SysmonEvent }
{ "type": "system_info",      "data": SystemInfo }
{ "type": "alert",            "data": Alert }
{ "type": "browser_history",  "data": [ ...BrowserHistoryEntry ] }
{ "type": "pong",             "data": null }
```

### Flutter → Service (commands)
```json
{ "type": "ping" }
{ "type": "kill_process",      "pid": 1234 }
{ "type": "block_ip",          "ip": "1.2.3.4", "direction": "outbound" }
{ "type": "unblock_ip",        "ip": "1.2.3.4" }
{ "type": "isolate_machine" }
{ "type": "unisolate_machine" }
{ "type": "suspend_process",   "pid": 1234 }
{ "type": "flag_process",      "name": "notepad.exe" }
{ "type": "unflag_process",    "name": "notepad.exe" }
{ "type": "get_browser_history","browser": "all" }
{ "type": "get_installed_software" }
```

---

## Phase 0 — Project Scaffold & Connection

**Goal:** Both projects exist, connect to each other, exchange a ping/pong.
Nothing more.

### Windows Service Tasks
- [ ] Create new .NET 10 Worker Service project
  ```
  dotnet new worker -n EndpointMonitorService
  cd EndpointMonitorService
  dotnet add package Microsoft.Extensions.Hosting.WindowsServices
  dotnet add package Microsoft.AspNetCore
  ```
- [ ] Add ASP.NET Core to the Worker Service host
- [ ] Create a basic WebSocket endpoint at `/ws`
- [ ] Implement token authentication middleware:
  - Read `Authorization: Bearer <token>` header on WebSocket upgrade request
  - Compare against token in `appsettings.json`
  - Reject with 401 if missing or invalid
- [ ] Handle ping → respond with pong
- [ ] Add `appsettings.json` with:
  ```json
  {
    "Auth": { "Token": "CHANGE_THIS_TO_A_LONG_RANDOM_SECRET" },
    "Server": { "Port": 5000 }
  }
  ```
- [ ] Verify it runs as Administrator
- [ ] Test with a simple WebSocket client (e.g. Postman or wscat)

### Flutter App Tasks
- [ ] Create new Flutter project
  ```
  flutter create endpoint_monitor
  ```
- [ ] Add dependencies to pubspec.yaml:
  ```yaml
  web_socket_channel: ^2.4.0
  flutter_secure_storage: ^9.0.0
  flutter_bloc: ^8.1.0
  dio: ^5.4.0
  ```
- [ ] Create `ConnectionBloc` with states: Disconnected, Connecting, Connected, Error
- [ ] Create connection screen: input for host URL + token
- [ ] Save host URL and token to `flutter_secure_storage` on connect
- [ ] Load saved credentials on app launch
- [ ] On connect, open WebSocket, send ping, expect pong
- [ ] Show connected/disconnected status clearly in UI
- [ ] Handle disconnection gracefully with auto-reconnect (exponential backoff)

**Phase 0 complete when:** Flutter app connects to Windows service from the same machine, ping/pong works, auth token is validated.

---

## Phase 1 — Live Process Monitoring

**Goal:** Flutter app shows a live, auto-refreshing list of all running processes.

### Windows Service Tasks
- [ ] Add NuGet package: `System.Management`
- [ ] Create `ProcessCollector` class:
  - Use `ManagementObjectSearcher` with WMI query:
    ```sql
    SELECT ProcessId, Name, CommandLine, ParentProcessId,
           WorkingSetSize, CreationDate
    FROM Win32_Process
    ```
  - Map results to `ProcessInfo` model
  - Calculate CPU usage (requires two samples with a time delta)
- [ ] Create background polling loop in a `BackgroundService`:
  - Poll every 5 seconds
  - Serialize process list to JSON
  - Broadcast to all connected WebSocket clients
- [ ] Handle WMI access exceptions gracefully (some system processes restrict access)

### Flutter App Tasks
- [ ] Create `ProcessBloc` managing `List<ProcessInfo>` state
- [ ] Create Processes screen with:
  - Searchable list (filter by name or PID)
  - Each row: process name, PID, CPU%, memory, start time
  - Tap row to expand: full command line, parent PID
  - Sort options: by name, CPU, memory, PID
  - Auto-updates when new data arrives via WebSocket
- [ ] Show loading state on first connect
- [ ] Colour code high CPU/memory processes

**Phase 1 complete when:** Flutter shows live process list updating every 5 seconds, search and sort work, command line visible on tap.

---

## Phase 2 — Live Network Connections

**Goal:** Flutter app shows all active TCP/UDP connections in real time.

### Windows Service Tasks
- [ ] Create `NetworkCollector` class using WMI:
  ```sql
  SELECT LocalAddress, LocalPort, RemoteAddress, RemotePort,
         State, OwningProcess
  FROM MSFT_NetTCPConnection
  ```
  (Use `ROOT\StandardCimv2` namespace for MSFT_NetTCPConnection)
- [ ] For UDP, query `MSFT_NetUDPEndpoint`
- [ ] Join with process list to get process name per connection
- [ ] Poll every 5 seconds, broadcast to clients

### Flutter App Tasks
- [ ] Create `NetworkBloc` managing `List<NetworkConnection>` state
- [ ] Create Network screen with:
  - List of active connections
  - Each row: process name, local port, remote IP, remote port, state, protocol
  - Filter by protocol (TCP/UDP), by state (ESTABLISHED, LISTEN etc.)
  - Search by IP or process name
  - Tap row: show full connection details

**Phase 2 complete when:** Flutter shows live network connections, filterable by protocol and state.

---

## Phase 3 — Sysmon Event History

**Goal:** Flutter app shows a searchable, filterable historical event feed from Sysmon.

### Windows Service Tasks
- [ ] Verify Sysmon is installed and logging (prerequisite check on startup)
- [ ] Create `SysmonEventReader` class:
  - Use `System.Diagnostics.Eventing.Reader.EventLogReader`
  - Query log: `Microsoft-Windows-Sysmon/Operational`
  - Parse Event ID 1 (ProcessCreate), 3 (NetworkConnect),
    5 (ProcessTerminate), 22 (DnsQuery)
  - Map XML fields to `SysmonEvent` model
- [ ] Create `SysmonEventWatcher` using `EventLogWatcher`:
  - Subscribe to new events in real time
  - Push new events to connected clients immediately via WebSocket
- [ ] Create local SQLite database using SQLite-net:
  - Table: `SysmonEvents` (all fields from model + auto-increment id)
  - On startup: load last 24 hours of events from Event Log into DB
  - On new event: insert into DB and broadcast to clients
- [ ] Expose query endpoint: filter by date range, event type, process name

### Flutter App Tasks
- [ ] Add dependency: `intl` for date formatting
- [ ] Create `EventHistoryBloc`
- [ ] Create Event History screen:
  - Chronological feed of Sysmon events
  - Colour coded by event type (process=blue, network=green, dns=yellow, terminate=red)
  - Each row: timestamp, event type icon, process name, summary
  - Tap to expand: full details (command line, remote IP, DNS query etc.)
  - Filter bar: by type, by process name, by date range
  - Search: full text search across event fields
  - Real-time — new events appear at top as they arrive

**Phase 3 complete when:** Event history feed shows real-time Sysmon events, filtering and search work, historical events load on open.

---

## Phase 4 — System Overview Dashboard

**Goal:** A dashboard screen showing system health at a glance.

### Windows Service Tasks
- [ ] Create `SystemInfoCollector`:
  - CPU: `System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")`
  - RAM: WMI `Win32_OperatingSystem` (FreePhysicalMemory, TotalVisibleMemorySize)
  - Disk: `System.IO.DriveInfo`
  - Uptime: `System.Environment.TickCount64`
  - OS version: `System.Environment.OSVersion` + registry for patch level
  - Logged in users: WMI `Win32_LoggedOnUser`
- [ ] Poll every 10 seconds, broadcast `system_info` message

### Flutter App Tasks
- [ ] Add dependency: `fl_chart`
- [ ] Create Dashboard screen (home/landing screen):
  - Connection status badge (connected/disconnected + latency)
  - CPU usage gauge or sparkline
  - RAM used / total bar
  - Disk used / total bar
  - Uptime
  - OS version + patch level
  - Logged in users list
  - Quick summary counts: X processes, X connections, X events today

**Phase 4 complete when:** Dashboard shows live system health, is the first screen after connecting.

---

## Phase 5 — Browser History

**Goal:** Flutter app can request and view browser history from Chrome, Edge, and Firefox.

### Windows Service Tasks
- [ ] Create `BrowserHistoryReader` class:
  - **Chrome path:** `%LOCALAPPDATA%\Google\Chrome\User Data\Default\History`
  - **Edge path:** `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\History`
  - **Firefox path:** Find profile via `%APPDATA%\Mozilla\Firefox\profiles.ini`, then `places.sqlite`
- [ ] For Chrome/Edge (same SQLite schema):
  ```sql
  SELECT url, title, visit_count,
         datetime(last_visit_time/1000000-11644473600,'unixepoch') as visit_time
  FROM urls
  ORDER BY last_visit_time DESC
  LIMIT 500
  ```
  **Important:** Copy file to temp path before reading — browser locks it while open.
  ```csharp
  File.Copy(historyPath, tempPath, overwrite: true);
  // Read from tempPath
  ```
- [ ] For Firefox:
  ```sql
  SELECT p.url, p.title, p.visit_count, h.visit_date
  FROM moz_places p
  JOIN moz_historyvisits h ON p.id = h.place_id
  ORDER BY h.visit_date DESC
  LIMIT 500
  ```
- [ ] Handle case where browser is not installed gracefully
- [ ] Only read when requested via `get_browser_history` command — not on a polling loop

### Flutter App Tasks
- [ ] Create `BrowserHistoryBloc`
- [ ] Create Browser History screen:
  - Tab bar: All / Chrome / Edge / Firefox
  - List: favicon placeholder, title, URL, timestamp, visit count
  - Search by URL or title
  - Tap to copy URL
  - Pull-to-refresh to request fresh data
  - Show loading spinner while fetching

**Phase 5 complete when:** Browser history from all three browsers visible in Flutter, search works, tabs filter by browser.

---

## Phase 6 — Response Features (Securing the Endpoint)

**Goal:** Flutter app can take action on the endpoint — kill, block, isolate.

### Windows Service Tasks

#### Kill Process
```csharp
var process = Process.GetProcessById(pid);
process.Kill(entireProcessTree: true);
```
- [ ] Implement kill command handler
- [ ] Return success/failure response
- [ ] Protect against killing critical system processes (by name whitelist check)
- [ ] Log all response actions to local DB

#### Block IP (Firewall Rule)
```csharp
Process.Start("netsh", $"advfirewall firewall add rule name=\"EM_BLOCK_{ip}\" " +
  $"dir=out action=block remoteip={ip}");
```
- [ ] Implement block_ip command handler
- [ ] Implement unblock_ip: `netsh advfirewall firewall delete rule name="EM_BLOCK_{ip}"`
- [ ] Track all active blocks in local DB so they can be listed and reversed

#### Isolate Machine
- [ ] On isolate command:
  1. Add rule: block all inbound
  2. Add rule: block all outbound
  3. Add exception: allow the monitoring service port (preserve remote access)
- [ ] On unisolate command: remove isolation rules by name
- [ ] Track isolation state in memory + persist to local DB

#### Suspend Process
```csharp
// P/Invoke NtSuspendProcess
[DllImport("ntdll.dll")]
static extern uint NtSuspendProcess(IntPtr processHandle);
```
- [ ] Implement suspend via P/Invoke
- [ ] Implement resume via `NtResumeProcess`

#### Flag/Watchlist Process
- [ ] Maintain a list of flagged process names in local DB
- [ ] When a new Sysmon Event ID 1 fires for a flagged process, send high-severity Alert

### Flutter App Tasks
- [ ] Add `flutter_local_notifications` and configure for Android
- [ ] On each ProcessInfo row — long press context menu:
  - Kill Process (with confirmation dialog)
  - Suspend / Resume Process
  - Flag Process (add to watchlist)
- [ ] On each NetworkConnection row — long press context menu:
  - Block Remote IP (with confirmation dialog)
  - Unblock Remote IP
- [ ] Isolate Machine button — on Dashboard, prominent red button, double-confirm dialog
- [ ] Firewall Rules screen: list of active EM_ blocks with unblock option
- [ ] Watchlist screen: list of flagged process names, add/remove
- [ ] Alert notification: when service sends Alert message, show local push notification
- [ ] Response action feedback: show success/failure snackbar after every action

**Phase 6 complete when:** Can kill a process, block an IP, isolate the machine, and flag processes — all from the Flutter app with confirmation flows.

---

## Phase 7 — Alerts & Notifications

**Goal:** Proactive alerts pushed to phone for suspicious activity.

### Windows Service Tasks
- [ ] Create `AlertEngine` class that monitors incoming Sysmon events and applies rules:
  - **New outbound connection by browser to non-HTTP port** → medium alert
  - **Process with no parent PID** → low alert (potential process injection)
  - **Flagged process started** → high alert
  - **New software installed** (WMI `Win32_Product` change) → medium alert
  - **Connection to known bad IP** (maintain local blocklist in DB) → high alert
  - **PowerShell/cmd with encoded command** (check command line for `-enc` or `-encodedcommand`) → high alert
- [ ] Broadcast Alert messages to connected Flutter clients

### Flutter App Tasks
- [ ] `AlertsBloc` maintaining list of alerts
- [ ] Alerts screen: chronological list, colour coded by severity
- [ ] Filter by severity, by type, by date
- [ ] Tap alert to see related process/connection detail
- [ ] Mark alert as acknowledged
- [ ] Push notification for high severity alerts even when app is backgrounded
  (use `flutter_foreground_task` if needed — same pattern as Overwatch tracker)

**Phase 7 complete when:** High severity events arrive as push notifications, Alerts screen shows full history.

---

## Phase 8 — Installed Software & Extras

**Goal:** Remaining informational features.

### Windows Service Tasks
- [ ] Create `InstalledSoftwareCollector`:
  ```sql
  -- WMI query
  SELECT Name, Version, InstallDate, Vendor FROM Win32_Product
  ```
  Note: Win32_Product is slow — only query on demand, not polling.
  Alternative: Read registry keys directly for much faster results:
  `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`
- [ ] Return installed software list on `get_installed_software` command

### Flutter App Tasks
- [ ] Installed Software screen: searchable list of name, version, vendor, install date

---

## Phase 9 — Security Hardening & Production Readiness

**Goal:** Make the service safe to run exposed to the internet.

### Windows Service Tasks
- [ ] Upgrade from static token to JWT:
  - Issue JWT on first authenticated HTTP request
  - JWT contains expiry (configurable, default 30 days)
  - All WebSocket + HTTP requests validate JWT signature
- [ ] Add rate limiting to prevent brute force on auth endpoint
- [ ] Add IP allowlist option in `appsettings.json` (optional, off by default)
- [ ] Log all incoming connections with IP + timestamp to local DB
- [ ] TLS: add HTTPS/WSS support via ASP.NET Core HTTPS middleware
  (use Let's Encrypt cert or self-signed for local testing)
- [ ] Log all response actions (kill, block, isolate) with timestamp to audit log

### Flutter App Tasks
- [ ] Auth screen: token entry with show/hide toggle
- [ ] Token expiry handling: detect 401, prompt to re-authenticate
- [ ] Connection history: remember last 3 endpoints
- [ ] App lock: optional PIN/biometric to open the app

---

## Phase 10 — Multiple Endpoints (Stretch Goal)

**Goal:** Monitor more than one PC from the same Flutter app.

### Changes Required
- Flutter: endpoint selector on home screen, per-endpoint stored credentials
- Flutter: all blocs scoped per-endpoint
- Windows: no changes (each PC runs its own independent service instance)

---

## Phase 11 — Export & Reporting (Stretch Goal)

**Goal:** Export logs for offline review or incident reporting.

### Windows Service Tasks
- [ ] HTTP endpoint: `GET /export/events?from=&to=&format=json|csv`
- [ ] Returns Sysmon events in requested format from local DB

### Flutter App Tasks
- [ ] Export button on Event History screen
- [ ] Select date range, select format, download file to device

---

## Development Notes for Cursor AI Agents

### Naming Conventions
- C# classes: PascalCase. Methods: PascalCase. Fields: _camelCase.
- Dart classes: PascalCase. Methods/variables: camelCase.
- JSON fields: camelCase throughout.

### Error Handling
- Windows Service: every collector method must catch exceptions individually and log them.
  A failing collector must NOT crash the service or disconnect clients.
- Flutter: every Bloc must have an Error state. Network errors must show user-friendly messages.

### Logging (Windows Service)
Use `ILogger<T>` from `Microsoft.Extensions.Logging` — it is injected automatically
in Worker Services. Log every:
- Client connection/disconnection (with IP)
- Auth failure (with IP)
- Response action taken (kill/block/isolate) with timestamp and requesting IP
- Collector errors

### Testing During Development
1. Run Windows Service with `dotnet run` (as Administrator) during development
2. Note the port from console output
3. Connect Flutter app to `ws://YOUR_PC_IP:5000/ws?token=YOUR_TOKEN`
4. For remote testing: set up port forward on router → Windows PC port 5000
5. For production: migrate to Tailscale or Cloudflare Tunnel

### appsettings.json (Windows Service)
Never commit the real token to version control.
Add `appsettings.json` to `.gitignore`.
Provide an `appsettings.example.json` with placeholder values instead.

### State Persistence
The Windows Service should on startup:
- Load last 24h of Sysmon events from Event Log into SQLite
- Load flagged process list from SQLite
- Load active firewall blocks from SQLite
- Load isolation state from SQLite
So a service restart does not lose context.

---

## Recommended Build Order Summary

| Phase | Feature | Complexity |
|-------|---------|------------|
| 0 | Scaffold + Connection + Auth | Medium |
| 1 | Live Processes | Easy |
| 2 | Live Network Connections | Easy |
| 3 | Sysmon Event History | Medium |
| 4 | System Overview Dashboard | Easy |
| 5 | Browser History | Medium |
| 6 | Response Features | Hard |
| 7 | Alerts & Notifications | Medium |
| 8 | Installed Software | Easy |
| 9 | Security Hardening | Medium |
| 10 | Multiple Endpoints | Medium |
| 11 | Export & Reporting | Easy |

---

---

## Addendum A — Flutter Navigation Architecture

Define this in Phase 0 and never change it. Cursor must follow this structure
from the first screen built.

### Shell Structure
Use a **bottom navigation bar** with 5 top-level destinations:

```
Bottom Nav:
  1. Dashboard       (home icon)
  2. Processes       (cpu icon)
  3. Network         (wifi icon)
  4. Events          (history icon)
  5. More            (menu icon) → opens drawer or sub-screen list
```

The "More" tab covers: Browser History, Installed Software, Alerts, Firewall Rules, Watchlist, Settings.

### Routing
Use **go_router** package for all navigation. Add to pubspec.yaml:
```yaml
go_router: ^13.0.0
```

Define all routes in a single `app_router.dart` file at project root.
Named routes only — no anonymous push navigation anywhere in the codebase.

### Route Map
```
/                       → redirect to /dashboard if connected, /connect if not
/connect                → Connection / Auth screen
/dashboard              → Dashboard screen
/processes              → Process list screen
/processes/:pid         → Process detail screen (all events for that PID)
/network                → Network connections screen
/events                 → Sysmon event history screen
/browser                → Browser history screen
/software               → Installed software screen
/alerts                 → Alerts screen
/firewall               → Active firewall blocks screen
/watchlist              → Flagged processes screen
/settings               → Settings screen
```

### Connection Guard
All routes except `/connect` must check connection state via `ConnectionBloc`.
If not connected, redirect to `/connect` automatically.
Implement this as a `redirect` callback in go_router — do not handle it per-screen.

---

## Addendum B — Flutter Backgrounding & Foreground Task

Without this, the WebSocket connection dies when the phone locks or the app
is backgrounded. This must be implemented in **Phase 0**, not added later.

### Package
```yaml
flutter_foreground_task: ^8.0.0
```

### How It Works
A foreground service keeps a persistent notification in the Android notification
tray (required by Android for background execution). The WebSocket runs inside
this foreground task so it survives screen lock, app backgrounding, and
low-memory conditions.

### Implementation Pattern

**1. Initialise in main.dart before runApp:**
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const EndpointMonitorApp());
}
```

**2. Configure and start the foreground task on successful WebSocket connection:**
```dart
FlutterForegroundTask.startService(
  serviceId: 1000,
  notificationTitle: 'Endpoint Monitor',
  notificationText: 'Monitoring active',
  notificationIcon: NotificationIconData(
    resType: ResourceType.mipmap,
    resPrefix: ResourcePrefix.ic,
    name: 'launcher',
  ),
  callback: startCallback,
);
```

**3. The task handler manages the WebSocket:**
```dart
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(EndpointMonitorTaskHandler());
}

class EndpointMonitorTaskHandler extends TaskHandler {
  WebSocketChannel? _channel;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialise WebSocket connection here
  }

  @override
  void onReceiveData(Object data) {
    // Handle messages sent from Flutter UI to the task
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _channel?.sink.close();
  }
}
```

**4. Stop the foreground task on disconnect:**
```dart
FlutterForegroundTask.stopService();
```

### Android Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<service
  android:name="com.pravera.flutter_foreground_task.service.ForegroundTaskService"
  android:foregroundServiceType="dataSync"
  android:exported="false"/>
```

### Key Rule
The WebSocket channel lives inside the `TaskHandler`, not in any Flutter widget
or Bloc directly. The Flutter UI communicates with the task via
`FlutterForegroundTask.sendDataToTask()` and receives data via
`FlutterForegroundTask.addTaskDataCallback()`.

---

*Generated for the Endpoint Monitor project — Michael, 2026*
