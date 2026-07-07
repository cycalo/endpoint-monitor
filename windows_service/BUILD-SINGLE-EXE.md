# Building Endpoint Monitor as a single Windows executable

This project is an ASP.NET Core + Windows Service host. You can publish a **self-contained, single-file** `EndpointMonitorService.exe` that:

- Runs the web API and (when installed) the Windows Service.
- **Requests Administrator** when started interactively (double-click or `dotnet run` with the apphost), via `app.manifest` (`requireAdministrator`). This matches the need for WMI, Sysmon, firewall, and process actions documented in `RUN.txt`.

> **Windows Service accounts:** After you register the app with `sc create`, the SCM starts the process as **Local System** (or whatever account you configure). The UAC manifest applies to **interactive** launches, not to the service’s logon account.

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

## Run as Administrator (interactive)

The project references **`app.manifest`** with `requestedExecutionLevel` set to **`requireAdministrator`**. Published and regular builds of the **apphost** (`EndpointMonitorService.exe`) will trigger a UAC prompt when launched from Explorer or the console **unless** the shell is already elevated.

## Install as a Windows Service with automatic start

You can use the **system tray** (when running interactively): **Start with Windows (Windows Service)**. Approve the UAC prompt; the helper script creates or reconfigures the service **`EndpointMonitor`** and sets **start= auto**.

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

## Pairing when the tray is unavailable

The system tray only runs in **interactive** sessions. After installing as a Windows Service (Session 0), generate pairing codes by opening **`http://localhost:<port>/local/pair`** in a browser **on the monitored PC** (loopback only). The Flutter app can also reach the agent via **`GET /health`** before pairing.

## Optional: framework-dependent single file

Smaller on disk, but requires the matching .NET runtime installed on the PC:

```bat
dotnet publish -c Release -r win-x64 --self-contained false ^
  -p:PublishSingleFile=true
```
