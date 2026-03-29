# How to test Endpoint Monitor

This guide covers end-to-end testing of the **Windows service** (`windows_service/`) and the **Flutter Android app** (`flutter_app/`). Adjust paths if your clone lives elsewhere.

---

## Prerequisites

| Requirement | Why |
|-------------|-----|
| **Windows 10/11 PC** for the service | Collectors use WMI, Event Log, registry, `netsh`, etc. |
| **.NET 10 SDK** | Build and run the service |
| **Flutter SDK** + **Android toolchain** (device or emulator) | Mobile client |
| **Administrator** when running the service | WMI, Sysmon, firewall, process actions need elevation |
| **Same LAN or USB** (for ADB) | Phone must reach the PC’s IP and port |

Optional but recommended for full feature testing:

- **Sysmon** installed and logging (see `ENDPOINT_MONITOR_DEVELOPMENT_PLAN.md` prerequisites) — events/history and alert rules that depend on Sysmon will not work without it.

---

## 1. Configure the Windows service

1. Open a terminal **as Administrator**.

2. Go to the service project:

   ```bash
   cd windows_service
   ```

3. If you do not have `appsettings.json` yet, copy the example:

   ```bash
   cp appsettings.example.json appsettings.json
   ```

   On Windows PowerShell:

   ```powershell
   Copy-Item appsettings.example.json appsettings.json
   ```

4. Edit **`appsettings.json`**:

   - Set **`Auth:Token`** to a long random string (this is the shared secret for WebSocket and static auth).
   - Set **`Auth:JwtSigningKey`** to at least **32 characters** (required if you use `POST /api/auth/token` to mint JWTs).
   - Confirm **`Server:Port`** (default **5000**).

5. **Windows Firewall:** allow inbound TCP on that port for your test network profile, or temporarily allow the `dotnet` / `EndpointMonitorService` process when prompted.

---

## 2. Run the Windows service

From **`windows_service/`** (still elevated):

```bash
dotnet run
```

- Watch the console for **listening** on the configured port (Kestrel listens on all interfaces by default).
- Leave this process running while testing.

**Smoke checks (optional):**

- **HTTP (JWT):** `POST http://<PC_IP>:5000/api/auth/token` with JSON body `{"token":"<your Auth:Token>"}` should return a JWT when `JwtSigningKey` is valid.
- **Export:** `GET http://<PC_IP>:5000/export/events` with header `Authorization: Bearer <token>` (static token or JWT).

**WebSocket without the app:** use any client that supports custom headers and `ws://`, e.g.:

- Connect to `ws://<PC_IP>:5000/ws`
- Set header **`Authorization: Bearer <your Auth:Token>`**
- Send: `{"type":"ping"}`  
  Expect: `{"type":"pong","data":null}` (JSON field names are camelCase).

**NetworkTestProbe** (`tools/NetworkTestProbe/`)

**Minimal block test (recommended): one process, one IP, one port — no HTTPS/DNS, no local listener**

1. Pick a **literal** remote IP and port that accept TCP (e.g. resolve a host once: `nslookup example.com`, then use one IPv4 like `104.18.27.120` and port `443`).
2. Run:

```bash
dotnet run --project tools/NetworkTestProbe -- --simple-block-test --tcp-host 104.18.27.120 --tcp-port 443
```

3. In the app → **Network**, find **`NetworkTestProbe`** (or **`NetworkTestProbe.exe`**) and the row with **Remote** `104.18.27.120:443` (TCP **Established**), open details → **Block IP**.
4. The console should show **`[TCP] NOT_REACHABLE`** on the next cycle; **Unblock** in the app to recover **`OK`**.

This mode avoids CDN/HTTP pooling confusion: each cycle is only a **new raw TCP connect** to exactly that address.

---

A .NET 8 console helper for manual checks (Network tab, Sysmon, firewall block rules):

- Prints **PID** and **process name** so you can match **Processes → process detail** (`/processes/<pid>`) and rows on the **Network** tab.
- Binds a **TCP listener** on `127.0.0.1:<ephemeral port>` so you should see a **LISTEN** row for this PID.
- **Loops** (default **every 5 seconds** until you stop it): each cycle runs **HTTPS GET** (default `https://example.com/`), optional **raw TCP** to `--tcp-host` / `--tcp-port`, and **DNS** for `--dns-host` (default `example.com`). Good for Sysmon DNS/network noise if Sysmon is installed.
- **HTTPS connection pooling is off by default** (`PooledConnectionLifetime` / idle = zero) so each cycle opens a **new** TCP connection — otherwise `HttpClient` could **reuse** a socket created **before** you added a firewall rule and wrongly show **OK** after a block. Pass **`--http-pooling`** only if you intentionally want long-lived pooled connections (not for validating blocks).
- **`example.com` is a poor block test**: Cloudflare exposes many IPv4/IPv6 addresses; blocking **one** IP may not block HTTPS to the hostname. Prefer **`--tcp-host` / `--tcp-port`** to a **single** known IP, or a small host you control.

From the **repository root**:

```bash
dotnet run --project tools/NetworkTestProbe/NetworkTestProbe.csproj
```

Useful flags:

```bash
# Loop (default interval 5s); watch OK vs NOT_REACHABLE after you add/remove block rules
dotnet run --project tools/NetworkTestProbe -- --https-url "https://example.com/"

# Optional extra TCP probe (e.g. align with outbound TCP 443 to a host)
dotnet run --project tools/NetworkTestProbe -- --tcp-host example.com --tcp-port 443

# Optional: DNS target, interval, connect timeout
dotnet run --project tools/NetworkTestProbe -- --dns-host example.com --interval-seconds 10 --connect-timeout-seconds 8

# Old behavior: enable HTTP connection pooling (can hide firewall blocks — not for block validation)
dotnet run --project tools/NetworkTestProbe -- --http-pooling --https-url "https://example.com/"
```

Or run the built executable (path after `dotnet publish` / Release build):

```
tools/NetworkTestProbe/bin/Release/net8.0/NetworkTestProbe.exe
```

On the **Network** tab, if you **block** this probe’s remote IP, the live socket may disappear; the app keeps a **blocked** row with the **process name and PID captured at block time** so you can still tell which executable was affected.
---

## 3. Prepare the Android app

1. Connect a **physical device** (recommended for foreground service + notifications) or start an **emulator**.

2. Ensure the **phone can reach the PC**:

   - Same Wi‑Fi: use the PC’s **LAN IPv4** (e.g. `192.168.1.10`).
   - Emulator: often `10.0.2.2` maps to the host machine (check Flutter/Android docs for your setup).

3. From **`flutter_app/`**:

   ```bash
   flutter pub get
   flutter run
   ```

4. On **Android 13+**, accept **notifications** when prompted (foreground service shows a persistent notification).

---

## 4. Connect from the app

1. Open the app → **Connect** screen.

2. **Host:** enter the PC address **without** `ws://` if you use the short form, e.g.:

   - `192.168.1.10:5000`  
   The client normalizes this to **`ws://192.168.1.10:5000/ws`**.

   Or paste a full URL including path if you already use `ws://.../ws`.

3. **Token:** paste the exact same value as **`Auth:Token`** in `appsettings.json`.

4. Tap **Connect**. You should see a **foreground notification** (“Endpoint Monitor” / “Monitoring active”) and land on the main shell when connected.

5. If connection fails:

   - Confirm the service is running and **not** blocked by firewall.
   - Ping the PC from the phone’s network (or use browser to hit `http://PC_IP:5000` only if you add a health route; WebSocket path is `/ws`).
   - Verify token spelling and that the service was restarted after config changes.

---

## 5. Feature checklist (manual)

Use this as a regression list after changes.

| Area | What to verify |
|------|----------------|
| **Connection** | Connect screen → connected; disconnect from Dashboard (if available) or by stopping the service → UI shows disconnected / error. |
| **Dashboard** | `system_info` updates ~every **10s**; CPU/RAM/disk/uptime/OS; summary counts; **Isolate** shows two confirmation dialogs (do not use on a machine you need online unless intended). |
| **Processes** | List updates ~every **5s**; search/sort; expand row; **Kill/Suspend/Resume/Flag** (dangerous on real systems—use a test VM). |
| **Network** | List updates ~every **5s**; protocol/state filters; **Block/Unblock** IP (requires admin service). |
| **Events** | Sysmon events appear if Sysmon is installed; filters/search; export button hits HTTP (set **Settings → HTTP base** and token for JWT/static as needed). |
| **More → Browser** | History loads per browser tab (Chrome/Edge may need profile paths as on a normal user session). |
| **More → Software** | Installed list loads (registry-based). |
| **More → Alerts** | Alerts from server rules; high severity may trigger a **notification** (channel configured in app). |
| **Settings** | JWT exchange: set HTTP base + static token, **Exchange JWT** writes token to secure storage; **Remember endpoint** updates recent list on Connect. |

---

## 6. Automated tests

- **Flutter:** `cd flutter_app && flutter test`  
  Currently runs a minimal placeholder test; extend with widget/integration tests as needed.

- **Windows service:** no test project is included by default. Add `dotnet test` when you introduce test projects.

---

## 7. Security notes for testing

- Do **not** commit real **`appsettings.json`** secrets (see `.gitignore`).
- Treat **kill / isolate / firewall** actions as destructive; use a **VM** or dedicated test PC.
- For production, plan for **TLS (`wss://`)** and JWT rotation—see `TODO.md` and the development plan Phase 9.

---

## Quick reference

| Item | Value |
|------|--------|
| Default port | `5000` (from `Server:Port`) |
| WebSocket path | `/ws` |
| Auth header | `Authorization: Bearer <token>` |
| Service run | **Administrator** + `dotnet run` in `windows_service/` |
| Flutter run | `flutter run` in `flutter_app/` |

For gaps and follow-ups (command_result UX, TLS, etc.), see [`TODO.md`](TODO.md).
