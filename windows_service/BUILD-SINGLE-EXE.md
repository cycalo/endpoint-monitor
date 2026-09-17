# Building Endpoint Monitor as a single Windows executable

This project is an ASP.NET Core + Windows Service host with an optional **desktop setup console** (WPF). You can publish a **self-contained, single-file** `EndpointMonitorService.exe` that:

- Runs the web API and (when installed) the Windows Service.
- Opens a **desktop console** when launched interactively (pairing, devices, diagnostics, settings). Closing the console does **not** stop the agent.
- Uses **`asInvoker`** for interactive launches (no UAC on open). Elevation is requested only when you toggle **Start with Windows (Windows Service)** in Settings, or when you run the in-process agent without admin rights.

> **Windows Service accounts:** After you register the app with `sc create`, the SCM starts the process as **Local System** (or whatever account you configure). The service runs headless in Session 0 with no desktop UI.

## Prerequisites

- [.NET SDK](https://dotnet.microsoft.com/download) matching `TargetFramework` in `EndpointMonitorService.csproj` (e.g. .NET 10).
- Windows x64 (adjust `-r` if you need arm64).

## Recommended publish command (single file, self-contained)

From the `windows_service` folder:

```bat
dotnet publish -c Release -r win-x64 --self-contained true ^
  -p:PublishSingleFile=true ^
  -p:IncludeNativeLibrariesForSelfExtract=true ^
  -p:PublishReadyToRun=true
```

Output (typical):

`bin\Release\net10.0-windows\win-x64\publish\EndpointMonitorService.exe`

Copy `appsettings.json` (and optional `GeoLite2-City.mmdb`) next to that exe if they are not already included by your publish setup. The repo uses content items for the GeoIP file when present.

### Why not enable `PublishTrimmed` here?

Trimming can remove code ASP.NET Core discovers only at runtime. For a reliable agent build, keep trimming **off** unless you have tested your scenario thoroughly.

## Desktop console vs Windows Service

| Launch | What runs |
|--------|-----------|
| **Service at boot** (`sc create` + `start= auto`) | Headless agent only (Kestrel, collectors). No window. |
| **Double-click exe** (service already running) | Desktop console only — talks to `http://127.0.0.1:<port>/local/*`. Does not start a second agent. |
| **Double-click exe** (service not running) | In-process agent **and** desktop console (`dotnet run` dev path). |

The console can **minimize to the system tray** (Settings). Tray **Exit** closes the UI only; the Windows Service keeps running.

## Install as a Windows Service with automatic start

Open the desktop app → **Settings** → **Start with Windows (Windows Service)**. Approve the UAC prompt; the helper script creates or reconfigures the service **`EndpointMonitor`** and sets **start= auto**.

Manual equivalent (elevated Command Prompt), after replacing the path:

```bat
sc create EndpointMonitor binPath= "C:\full\path\to\EndpointMonitorService.exe" DisplayName= "Endpoint Monitor" start= auto
sc description EndpointMonitor "Monitors endpoint telemetry for the Endpoint Monitor mobile app."
sc start EndpointMonitor
```

To set **manual** start (no auto-run at boot):

```bat
sc config EndpointMonitor start= demand
```

To remove the service:

```bat
sc stop EndpointMonitor
sc delete EndpointMonitor
```

## Single instance / port conflicts

Only one process should own the configured HTTP port (see `Server:Port` in `appsettings.json`). If an interactive session is already listening, **`sc start`** may fail or the service may exit until the port is free.

## Pairing when the desktop app is closed

After installing as a Windows Service (Session 0), open the desktop app on the monitored PC and use the **Pair** screen. The Flutter app can reach the agent via **`GET /health`** before pairing.

## Optional: framework-dependent single file

Smaller on disk, but requires the matching .NET runtime installed on the PC:

```bat
dotnet publish -c Release -r win-x64 --self-contained false ^
  -p:PublishSingleFile=true
```
