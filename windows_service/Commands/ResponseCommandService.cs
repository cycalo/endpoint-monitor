using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Linq;
using System.Diagnostics;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Forms;
using EndpointMonitorService.Database;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Options;
using Microsoft.Win32;

namespace EndpointMonitorService.Commands;

public sealed class ResponseCommandService(
    ILogger<ResponseCommandService> logger,
    AppDatabase database,
    IOptions<ServerOptions> serverOptions,
    WebSocketConnectionManager webSockets,
    Browser.BrowserHistoryReader browserHistoryReader,
    Collectors.InstalledSoftwareCollector installedSoftwareCollector,
    VirusTotalReputationService virusTotal,
    ThreatIntelUpdater threatIntel)
{
    /// <summary>
    /// Firewall snapshots must always include <c>sourceProcessName</c> on each block (string or JSON null).
    /// <see cref="AppJson.Options"/> uses <see cref="JsonIgnoreCondition.WhenWritingNull"/>, which would omit
    /// nulls if we used the global options here.
    /// </summary>
    private static readonly JsonSerializerOptions FirewallSnapshotJsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never
    };

    private sealed record FirewallBlockJson(
        string blockKind,
        string? ip,
        string direction,
        string createdAt,
        string? sourceProcessName,
        int? remotePort,
        string? expiresAt,
        string? processName,
        string? executablePath);

    private static readonly HashSet<string> ProtectedNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "System", "Registry", "csrss.exe", "lsass.exe", "smss.exe", "wininit.exe", "services.exe",
        "winlogon.exe", "fontdrvhost.exe", "sihost.exe"
    };

    public async Task<CommandResult> HandleAsync(string type, JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            return type switch
            {
                "kill_process" => await KillAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "block_ip" => await BlockIpAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "unblock_ip" => await UnblockIpAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "isolate_machine" => await IsolateAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "unisolate_machine" => await UnisolateAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "suspend_process" => await SuspendAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "resume_process" => await ResumeAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "flag_process" => await FlagAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "unflag_process" => await UnflagAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "get_browser_history" => await GetBrowserHistoryAsync(root, cancellationToken).ConfigureAwait(false),
                "get_installed_software" => await GetInstalledSoftwareAsync(cancellationToken).ConfigureAwait(false),
                "uninstall_software" => await UninstallSoftwareAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "get_recent_events" => await GetRecentEventsAsync(root, cancellationToken).ConfigureAwait(false),
                "ack_alert" => await AckAlertAsync(root, cancellationToken).ConfigureAwait(false),
                "get_firewall_snapshot" => await GetFirewallSnapshotAsync(cancellationToken).ConfigureAwait(false),
                "get_flagged_processes" => await GetFlaggedProcessesAsync(cancellationToken).ConfigureAwait(false),
                "block_outbound_port" => await BlockOutboundPortAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "block_process" => await BlockProcessAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "unblock_process" => await UnblockProcessAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "get_timeline" => await GetTimelineAsync(root, cancellationToken).ConfigureAwait(false),
                "check_reputation" => await CheckReputationAsync(root, cancellationToken).ConfigureAwait(false),
                "get_threat_intel_status" => await GetThreatIntelStatusAsync(cancellationToken).ConfigureAwait(false),
                "get_threat_intel_entries" => await GetThreatIntelEntriesAsync(cancellationToken).ConfigureAwait(false),
                "refresh_threat_intel" => await RefreshThreatIntelAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "lock_screen" => await LockScreenAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "logoff_user" => await LogoffUserAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "restart_machine" => await RestartMachineAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "shutdown_machine" => await ShutdownMachineAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "sleep_machine" => await SleepMachineAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "cancel_shutdown" => await CancelShutdownAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "turn_off_display" => await TurnOffDisplayAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "set_volume" => await SetVolumeAsync(root, clientIp, cancellationToken).ConfigureAwait(false),
                "toggle_mute" => await ToggleMuteAsync(clientIp, cancellationToken).ConfigureAwait(false),
                "capture_desktop_screenshot" => await CaptureDesktopScreenshotAsync(clientIp, cancellationToken).ConfigureAwait(false),
                _ => new CommandResult(false, type, "unknown_command")
            };
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Command {Type} failed", type);
            return new CommandResult(false, type, ex.Message);
        }
    }

    private async Task<CommandResult> KillAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        if (!root.TryGetProperty("pid", out var pidEl) || !pidEl.TryGetInt32(out var pid))
            return new CommandResult(false, "kill_process", "invalid_pid");

        var name = GetProcessName(pid);
        if (name != null && ProtectedNames.Contains(name))
            return new CommandResult(false, "kill_process", "protected_process");

        try
        {
            using var p = Process.GetProcessById(pid);
            p.Kill(entireProcessTree: true);
            await database.AppendAuditAsync("kill_process", $"pid={pid}", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "kill_process", "ok", null, pid);
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "kill_process", ex.Message, null, pid);
        }
    }

    private static string? GetProcessName(int pid)
    {
        try
        {
            using var p = Process.GetProcessById(pid);
            return p.ProcessName + ".exe";
        }
        catch
        {
            return null;
        }
    }

    private static string NormalizeFirewallDirection(string? dir)
    {
        var d = (dir ?? "outbound").Trim().ToLowerInvariant();
        return d switch
        {
            "inbound" => "inbound",
            "both" => "both",
            _ => "outbound"
        };
    }

    private static string SanitizeIpForRuleName(string ip) =>
        ip.Replace(".", "_", StringComparison.Ordinal)
            .Replace(":", "_", StringComparison.Ordinal)
            .Replace("%", "_", StringComparison.Ordinal);

    private static string? ParseExpiresAtUtc(JsonElement root)
    {
        if (!root.TryGetProperty("expiresInHours", out var el)) return null;
        if (el.ValueKind == JsonValueKind.Null) return null;
        if (el.ValueKind == JsonValueKind.String)
        {
            var s = el.GetString();
            if (string.IsNullOrEmpty(s) || s.Equals("permanent", StringComparison.OrdinalIgnoreCase))
                return null;
            if (int.TryParse(s, out var hs) && hs > 0) return DateTime.UtcNow.AddHours(hs).ToString("O");
            return null;
        }
        if (el.TryGetInt32(out var h) && h > 0) return DateTime.UtcNow.AddHours(h).ToString("O");
        return null;
    }

    private async Task<CommandResult> BlockIpAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var ip = root.GetProperty("ip").GetString() ?? "";
        var dirRaw = root.TryGetProperty("direction", out var d) ? d.GetString() : null;
        var dir = NormalizeFirewallDirection(dirRaw);
        var sourceProcess = root.TryGetProperty("sourceProcess", out var sp) ? sp.GetString() : null;
        var remotePort = 0;
        if (root.TryGetProperty("port", out var portEl) && portEl.TryGetInt32(out var rp) && rp is >= 1 and <= 65535)
            remotePort = rp;
        var expiresAt = ParseExpiresAtUtc(root);
        var portArgs = remotePort > 0 ? $" remoteport={remotePort}" : "";

        var ruleSan = SanitizeIpForRuleName(ip);
        var outRule = $"EM_BLOCK_{ruleSan}";
        var inRule = $"{outRule}_in";

        if (dir is "outbound" or "both")
            RunNetsh($"advfirewall firewall add rule name=\"{outRule}\" dir=out action=block remoteip={ip}{portArgs}");
        if (dir is "inbound" or "both")
            RunNetsh($"advfirewall firewall add rule name=\"{inRule}\" dir=in action=block remoteip={ip}{portArgs}");

        await database.AddFirewallBlockAsync(ip, dir, sourceProcess, remotePort, expiresAt, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("block_ip", ip, clientIp, cancellationToken).ConfigureAwait(false);
        await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "block_ip", "ok");
    }

    private async Task<CommandResult> BlockOutboundPortAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        if (!root.TryGetProperty("port", out var pEl) || !pEl.TryGetInt32(out var port) || port is < 1 or > 65535)
            return new CommandResult(false, "block_outbound_port", "invalid_port");
        var key = $"port:{port}";
        var expiresAt = ParseExpiresAtUtc(root);
        RunNetsh($"advfirewall firewall delete rule name=\"EM_BLOCK_PORT_{port}_out\"");
        RunNetsh($"advfirewall firewall add rule name=\"EM_BLOCK_PORT_{port}_out\" dir=out action=block protocol=tcp remoteport={port}");
        await database.AddFirewallBlockAsync(key, "outbound", null, port, expiresAt, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("block_outbound_port", key, clientIp, cancellationToken).ConfigureAwait(false);
        await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "block_outbound_port", "ok");
    }

    private static string? TryGetExecutablePathForProcessName(string processName)
    {
        try
        {
            var n = processName.Replace("'", "''", StringComparison.Ordinal);
            using var searcher = new ManagementObjectSearcher($"SELECT ExecutablePath FROM Win32_Process WHERE Name = '{n}'");
            foreach (var o in searcher.Get())
            {
                if (o is ManagementObject mo)
                {
                    var path = mo["ExecutablePath"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(path)) return path;
                }
            }
        }
        catch
        {
            // ignore
        }
        return null;
    }

    private static string ProcessFirewallRuleKey(string processName, string dir) =>
        $"EM_PROC_{SanitizeIpForRuleName(processName)}_{dir}";

    private async Task<CommandResult> BlockProcessAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var name = root.GetProperty("name").GetString() ?? "";
        if (string.IsNullOrWhiteSpace(name))
            return new CommandResult(false, "block_process", "invalid_name");
        if (!name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
            name += ".exe";
        var dir = NormalizeFirewallDirection(root.TryGetProperty("direction", out var d) ? d.GetString() : null);
        var path = TryGetExecutablePathForProcessName(name);
        if (string.IsNullOrWhiteSpace(path))
            return new CommandResult(false, "block_process", "process_not_running_or_path_unavailable");
        var ruleKey = ProcessFirewallRuleKey(name, dir);
        var escaped = path.Replace("\"", "\\\"", StringComparison.Ordinal);
        if (dir is "outbound" or "both")
        {
            RunNetsh($"advfirewall firewall delete rule name=\"{ruleKey}_out\"");
            RunNetsh($"advfirewall firewall add rule name=\"{ruleKey}_out\" dir=out action=block program=\"{escaped}\"");
        }
        if (dir is "inbound" or "both")
        {
            RunNetsh($"advfirewall firewall delete rule name=\"{ruleKey}_in\"");
            RunNetsh($"advfirewall firewall add rule name=\"{ruleKey}_in\" dir=in action=block program=\"{escaped}\"");
        }
        var expiresAt = ParseExpiresAtUtc(root);
        await database.AddFirewallProcessBlockAsync(ruleKey, name, dir, path, expiresAt, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("block_process", name, clientIp, cancellationToken).ConfigureAwait(false);
        await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "block_process", "ok");
    }

    private async Task<CommandResult> UnblockProcessAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var name = root.GetProperty("name").GetString() ?? "";
        if (!name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
            name += ".exe";
        var dir = NormalizeFirewallDirection(root.TryGetProperty("direction", out var d) ? d.GetString() : null);
        var ruleKey = ProcessFirewallRuleKey(name, dir);
        RunNetsh($"advfirewall firewall delete rule name=\"{ruleKey}_out\"");
        RunNetsh($"advfirewall firewall delete rule name=\"{ruleKey}_in\"");
        await database.RemoveFirewallProcessBlockAsync(ruleKey, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("unblock_process", name, clientIp, cancellationToken).ConfigureAwait(false);
        await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "unblock_process", "ok");
    }

    private async Task<CommandResult> UnblockIpAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var ip = root.GetProperty("ip").GetString() ?? "";
        if (ip.StartsWith("port:", StringComparison.OrdinalIgnoreCase) &&
            int.TryParse(ip.AsSpan(5), out var p) && p is >= 1 and <= 65535)
        {
            RunNetsh($"advfirewall firewall delete rule name=\"EM_BLOCK_PORT_{p}_out\"");
            await database.RemoveFirewallBlockAsync(ip, cancellationToken).ConfigureAwait(false);
            await database.AppendAuditAsync("unblock_ip", ip, clientIp, cancellationToken).ConfigureAwait(false);
            await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "unblock_ip", "ok");
        }
        var ruleSan = SanitizeIpForRuleName(ip);
        var outRule = $"EM_BLOCK_{ruleSan}";
        var inRule = $"{outRule}_in";
        RunNetsh($"advfirewall firewall delete rule name=\"{outRule}\"");
        RunNetsh($"advfirewall firewall delete rule name=\"{inRule}\"");
        await database.RemoveFirewallBlockAsync(ip, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("unblock_ip", ip, clientIp, cancellationToken).ConfigureAwait(false);
        await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "unblock_ip", "ok");
    }

    public async Task PurgeExpiredFirewallBlocksAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var ipRows = await database.GetFirewallBlocksAsync(cancellationToken).ConfigureAwait(false);
        foreach (var row in ipRows)
        {
            if (string.IsNullOrEmpty(row.ExpiresAt)) continue;
            if (!DateTime.TryParse(row.ExpiresAt, out var exp) || exp > now) continue;
            var json = JsonSerializer.SerializeToElement(new Dictionary<string, string> { ["ip"] = row.Ip });
            await UnblockIpAsync(json, null, cancellationToken).ConfigureAwait(false);
        }
        var procRows = await database.GetFirewallProcessBlocksAsync(cancellationToken).ConfigureAwait(false);
        foreach (var row in procRows)
        {
            if (string.IsNullOrEmpty(row.ExpiresAt)) continue;
            if (!DateTime.TryParse(row.ExpiresAt, out var exp) || exp > now) continue;
            var json = JsonSerializer.SerializeToElement(new Dictionary<string, string> { ["name"] = row.ProcessName, ["direction"] = row.Direction });
            await UnblockProcessAsync(json, null, cancellationToken).ConfigureAwait(false);
        }
    }

    private async Task<CommandResult> IsolateAsync(string? clientIp, CancellationToken cancellationToken)
    {
        var port = serverOptions.Value.Port;
        RunNetsh("advfirewall firewall add rule name=\"EM_ISOLATE_BLOCK_IN\" dir=in action=block");
        RunNetsh("advfirewall firewall add rule name=\"EM_ISOLATE_BLOCK_OUT\" dir=out action=block");
        RunNetsh($"advfirewall firewall add rule name=\"EM_ISOLATE_ALLOW_MONITOR\" dir=in action=allow protocol=TCP localport={port}");
        RunNetsh($"advfirewall firewall add rule name=\"EM_ISOLATE_ALLOW_MONITOR_OUT\" dir=out action=allow protocol=TCP localport={port}");
        await database.SetIsolationAsync(true, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("isolate_machine", "on", clientIp, cancellationToken).ConfigureAwait(false);
        await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "isolate_machine", "ok");
    }

    private async Task<CommandResult> UnisolateAsync(string? clientIp, CancellationToken cancellationToken)
    {
        RunNetsh("advfirewall firewall delete rule name=\"EM_ISOLATE_BLOCK_IN\"");
        RunNetsh("advfirewall firewall delete rule name=\"EM_ISOLATE_BLOCK_OUT\"");
        RunNetsh("advfirewall firewall delete rule name=\"EM_ISOLATE_ALLOW_MONITOR\"");
        RunNetsh("advfirewall firewall delete rule name=\"EM_ISOLATE_ALLOW_MONITOR_OUT\"");
        await database.SetIsolationAsync(false, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("unisolate_machine", "off", clientIp, cancellationToken).ConfigureAwait(false);
        await BroadcastFirewallAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "unisolate_machine", "ok");
    }

    private async Task<JsonElement> BuildFirewallDataElementAsync(CancellationToken cancellationToken)
    {
        var isolated = await database.GetIsolationAsync(cancellationToken).ConfigureAwait(false);
        var rows = await database.GetFirewallBlocksAsync(cancellationToken).ConfigureAwait(false);
        var blocks = new List<FirewallBlockJson>();
        foreach (var b in rows)
        {
            var kind = b.Ip.StartsWith("port:", StringComparison.OrdinalIgnoreCase) ? "port" : "ip";
            blocks.Add(new FirewallBlockJson(
                kind,
                b.Ip,
                b.Direction,
                b.CreatedAt,
                string.IsNullOrEmpty(b.SourceProcessName) ? null : b.SourceProcessName,
                b.RemotePort == 0 ? null : b.RemotePort,
                string.IsNullOrEmpty(b.ExpiresAt) ? null : b.ExpiresAt,
                null,
                null));
        }
        foreach (var p in await database.GetFirewallProcessBlocksAsync(cancellationToken).ConfigureAwait(false))
        {
            blocks.Add(new FirewallBlockJson(
                "process",
                null,
                p.Direction,
                p.CreatedAt,
                null,
                null,
                string.IsNullOrEmpty(p.ExpiresAt) ? null : p.ExpiresAt,
                p.ProcessName,
                string.IsNullOrEmpty(p.ExecutablePath) ? null : p.ExecutablePath));
        }
        return JsonSerializer.SerializeToElement(new { isolated, blocks }, FirewallSnapshotJsonOptions);
    }

    private async Task<CommandResult> GetFirewallSnapshotAsync(CancellationToken cancellationToken)
    {
        var data = await BuildFirewallDataElementAsync(cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "get_firewall_snapshot", "ok", data);
    }

    private async Task BroadcastFirewallAsync(CancellationToken cancellationToken)
    {
        try
        {
            var data = await BuildFirewallDataElementAsync(cancellationToken).ConfigureAwait(false);
            var json = JsonSerializer.Serialize(new { type = "firewall", data }, AppJson.Options);
            await webSockets.BroadcastAsync(Encoding.UTF8.GetBytes(json), cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Firewall broadcast failed");
        }
    }

    private async Task<CommandResult> SuspendAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        if (!root.TryGetProperty("pid", out var pidEl) || !pidEl.TryGetInt32(out var pid))
            return new CommandResult(false, "suspend_process", "invalid_pid");
        if (!NativeMethods.TryOpenProcess(pid, out var handle))
            return new CommandResult(false, "suspend_process", "open_failed", null, pid);
        try
        {
            var s = NativeMethods.NtSuspendProcess(handle);
            await database.AppendAuditAsync("suspend_process", $"pid={pid}", clientIp, cancellationToken).ConfigureAwait(false);
            return s == 0
                ? new CommandResult(true, "suspend_process", "ok", null, pid)
                : new CommandResult(false, "suspend_process", $"ntstatus={s}", null, pid);
        }
        finally
        {
            NativeMethods.CloseHandle(handle);
        }
    }

    private async Task<CommandResult> ResumeAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        if (!root.TryGetProperty("pid", out var pidEl) || !pidEl.TryGetInt32(out var pid))
            return new CommandResult(false, "resume_process", "invalid_pid");
        if (!NativeMethods.TryOpenProcess(pid, out var handle))
            return new CommandResult(false, "resume_process", "open_failed", null, pid);
        try
        {
            var s = NativeMethods.NtResumeProcess(handle);
            await database.AppendAuditAsync("resume_process", $"pid={pid}", clientIp, cancellationToken).ConfigureAwait(false);
            return s == 0
                ? new CommandResult(true, "resume_process", "ok", null, pid)
                : new CommandResult(false, "resume_process", $"ntstatus={s}", null, pid);
        }
        finally
        {
            NativeMethods.CloseHandle(handle);
        }
    }

    private async Task<CommandResult> FlagAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var name = root.GetProperty("name").GetString() ?? "";
        await database.AddFlagAsync(name, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("flag_process", name, clientIp, cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "flag_process", "ok");
    }

    private async Task<CommandResult> UnflagAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var name = root.GetProperty("name").GetString() ?? "";
        await database.RemoveFlagAsync(name, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("unflag_process", name, clientIp, cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "unflag_process", "ok");
    }

    private async Task<CommandResult> GetBrowserHistoryAsync(JsonElement root, CancellationToken cancellationToken)
    {
        var browser = root.TryGetProperty("browser", out var b) ? b.GetString() ?? "all" : "all";
        var entries = await browserHistoryReader.ReadAsync(browser, cancellationToken).ConfigureAwait(false);
        var data = JsonSerializer.SerializeToElement(entries, AppJson.Options);
        return new CommandResult(true, "get_browser_history", "ok", data);
    }

    private async Task<CommandResult> GetInstalledSoftwareAsync(CancellationToken cancellationToken)
    {
        var items = await installedSoftwareCollector.CollectAsync(cancellationToken).ConfigureAwait(false);
        var data = JsonSerializer.SerializeToElement(items, AppJson.Options);
        return new CommandResult(true, "get_installed_software", "ok", data);
    }

    private async Task<CommandResult> UninstallSoftwareAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var subKeyName = root.TryGetProperty("registrySubKey", out var sk) ? sk.GetString() ?? "" : "";
        if (string.IsNullOrWhiteSpace(subKeyName))
            return new CommandResult(false, "uninstall_software", "invalid_registry_subkey");
        if (subKeyName.Contains('\\') || subKeyName.Contains('/') || subKeyName.Contains("..", StringComparison.Ordinal))
            return new CommandResult(false, "uninstall_software", "invalid_registry_subkey");

        using var appKey = OpenUninstallSubKey(subKeyName);
        if (appKey == null)
            return new CommandResult(false, "uninstall_software", "not_found");

        var noRemove = appKey.GetValue("NoRemove");
        if (noRemove is int nr && nr != 0)
            return new CommandResult(false, "uninstall_software", "no_remove");

        var quiet = appKey.GetValue("QuietUninstallString")?.ToString();
        var normal = appKey.GetValue("UninstallString")?.ToString();
        var uninstallCmd = !string.IsNullOrWhiteSpace(quiet) ? quiet : normal;
        if (string.IsNullOrWhiteSpace(uninstallCmd))
            return new CommandResult(false, "uninstall_software", "no_uninstall_string");

        var displayName = appKey.GetValue("DisplayName")?.ToString() ?? subKeyName;

        try
        {
            using var p = Process.Start(new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = "/c " + uninstallCmd,
                UseShellExecute = true,
            });
            if (p == null)
                return new CommandResult(false, "uninstall_software", "start_failed");

            await database.AppendAuditAsync("uninstall_software", displayName, clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "uninstall_software", "ok");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "uninstall_software", ex.Message);
        }
    }

    private static RegistryKey? OpenUninstallSubKey(string subKeyName)
    {
        (RegistryKey Root, string Path)[] paths =
        [
            (Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            (Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
            (Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
        ];
        foreach (var (root, path) in paths)
        {
            var k = root.OpenSubKey(path + "\\" + subKeyName);
            if (k != null) return k;
        }
        return null;
    }

    private async Task<CommandResult> GetFlaggedProcessesAsync(CancellationToken cancellationToken)
    {
        var rows = await database.GetFlaggedProcessesAsync(cancellationToken).ConfigureAwait(false);
        var list = rows.Select(r => new { name = r.Name, addedAt = r.AddedAt }).ToList();
        var data = JsonSerializer.SerializeToElement(list, AppJson.Options);
        return new CommandResult(true, "get_flagged_processes", "ok", data);
    }

    private async Task<CommandResult> GetRecentEventsAsync(JsonElement root, CancellationToken cancellationToken)
    {
        var limit = root.TryGetProperty("limit", out var limitEl) && limitEl.TryGetInt32(out var v)
            ? Math.Clamp(v, 1, 5000)
            : 500;
        var processFilter = root.TryGetProperty("processFilter", out var pf) ? pf.GetString() : null;
        var typeFilter = root.TryGetProperty("typeFilter", out var tf) ? tf.GetString() : null;
        DateTime? from = null;
        DateTime? to = null;
        if (root.TryGetProperty("from", out var fromEl) && fromEl.ValueKind == JsonValueKind.String &&
            DateTime.TryParse(fromEl.GetString(), out var f))
            from = f.ToUniversalTime();
        if (root.TryGetProperty("to", out var toEl) && toEl.ValueKind == JsonValueKind.String &&
            DateTime.TryParse(toEl.GetString(), out var t))
            to = t.ToUniversalTime();
        var rows = await database.QuerySysmonAsync(
            from: from,
            to: to,
            typeFilter: typeFilter,
            processFilter: processFilter,
            limit: limit,
            cancellationToken: cancellationToken).ConfigureAwait(false);
        var items = rows.Select(r => new Models.SysmonEvent
        {
            EventId = r.EventId,
            Timestamp = r.Timestamp,
            Type = r.Type,
            Pid = r.Pid,
            ProcessName = r.ProcessName,
            CommandLine = r.CommandLine,
            ParentPid = r.ParentPid,
            RemoteAddress = r.RemoteAddress,
            RemotePort = r.RemotePort,
            DnsQuery = r.DnsQuery,
            RawXml = r.RawXml
        }).ToList();
        var data = JsonSerializer.SerializeToElement(items, AppJson.Options);
        return new CommandResult(true, "get_recent_events", "ok", data);
    }

    private async Task<CommandResult> AckAlertAsync(JsonElement root, CancellationToken cancellationToken)
    {
        var id = root.GetProperty("id").GetString() ?? "";
        await database.AckAlertAsync(id, cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "ack_alert", "ok");
    }

    private async Task<CommandResult> GetTimelineAsync(JsonElement root, CancellationToken cancellationToken)
    {
        var hours = root.TryGetProperty("hours", out var h) && h.TryGetInt32(out var hv) ? Math.Clamp(hv, 1, 168) : 24;
        var raw = await database.GetTimelineAsync(hours, cancellationToken).ConfigureAwait(false);
        var ordered = raw.OrderBy(x => x.HourStart, StringComparer.Ordinal).ToList();
        var sums = ordered
            .Select(d => d.ProcessCreate + d.NetworkConnect + d.DnsQuery)
            .ToList();
        var maxSum = sums.Count == 0 ? 0 : sums.Max();
        var heatmap = new List<object>(ordered.Count);
        for (var i = 0; i < ordered.Count; i++)
        {
            var d = ordered[i];
            var sum = sums[i];
            var activityLevel = maxSum <= 0
                ? 0
                : (int)Math.Round(10.0 * sum / maxSum, MidpointRounding.AwayFromZero);
            activityLevel = Math.Clamp(activityLevel, 0, 10);
            heatmap.Add(new
            {
                hour = i,
                hourStartUtc = d.HourStart,
                activityLevel,
                hasAlert = d.Alerts > 0
            });
        }

        var data = JsonSerializer.SerializeToElement(new
        {
            buckets = heatmap,
            generatedAt = DateTime.UtcNow.ToString("O")
        }, AppJson.Options);
        return new CommandResult(true, "get_timeline", "ok", data);
    }

    private async Task<CommandResult> CheckReputationAsync(JsonElement root, CancellationToken cancellationToken)
    {
        if (!root.TryGetProperty("pid", out var pidEl) || !pidEl.TryGetInt32(out var pid))
            return new CommandResult(false, "check_reputation", "invalid_pid");
        var data = await virusTotal.CheckProcessExecutableAsync(pid, cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "check_reputation", "ok", data);
    }

    private static JsonElement BuildThreatIntelStatusData(
        IReadOnlyList<BadIpRow> active,
        ThreatIntelUpdater intel)
    {
        var feeds = active
            .GroupBy(r => string.IsNullOrWhiteSpace(r.Source) ? "Other" : r.Source, StringComparer.OrdinalIgnoreCase)
            .Select(g => new { name = g.Key, count = g.Count() })
            .OrderByDescending(x => x.count)
            .ThenBy(x => x.name, StringComparer.OrdinalIgnoreCase)
            .ToList();
        return JsonSerializer.SerializeToElement(new
        {
            entryCount = active.Count,
            lastRunUtc = intel.LastSuccessfulRunUtc?.UtcDateTime.ToString("O"),
            lastEntriesWritten = intel.LastEntriesWritten,
            lastError = intel.LastError,
            feeds
        }, AppJson.Options);
    }

    private async Task<CommandResult> GetThreatIntelStatusAsync(CancellationToken cancellationToken)
    {
        var active = await database.GetActiveBadIpsAsync(cancellationToken).ConfigureAwait(false);
        var data = BuildThreatIntelStatusData(active, threatIntel);
        return new CommandResult(true, "get_threat_intel_status", "ok", data);
    }

    private async Task<CommandResult> GetThreatIntelEntriesAsync(CancellationToken cancellationToken)
    {
        var active = await database.GetActiveBadIpsAsync(cancellationToken).ConfigureAwait(false);
        var items = active.Select(r => new { r.Ip, r.Category, r.Source }).ToList();
        var data = JsonSerializer.SerializeToElement(new { items }, AppJson.Options);
        return new CommandResult(true, "get_threat_intel_entries", "ok", data);
    }

    private async Task<CommandResult> RefreshThreatIntelAsync(string? clientIp, CancellationToken cancellationToken)
    {
        await threatIntel.RunUpdateAsync(cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("refresh_threat_intel", "ok", clientIp, cancellationToken).ConfigureAwait(false);
        var active = await database.GetActiveBadIpsAsync(cancellationToken).ConfigureAwait(false);
        var data = BuildThreatIntelStatusData(active, threatIntel);
        return new CommandResult(true, "refresh_threat_intel", "ok", data);
    }

    private static int ParseDelaySeconds(JsonElement root)
    {
        if (!root.TryGetProperty("delaySeconds", out var el)) return 0;
        if (el.TryGetInt32(out var d)) return Math.Clamp(d, 0, 300);
        return 0;
    }

    private async Task<CommandResult> LockScreenAsync(string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("rundll32.exe", "user32.dll,LockWorkStation")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
            });
            p?.WaitForExit(30_000);
            await database.AppendAuditAsync("lock_screen", "ok", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "lock_screen", "Screen locked");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "lock_screen", ex.Message);
        }
    }

    private async Task<CommandResult> LogoffUserAsync(string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("shutdown", "/l")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
            });
            p?.WaitForExit(60_000);
            await database.AppendAuditAsync("logoff_user", "ok", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "logoff_user", "Current user logged off");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "logoff_user", ex.Message);
        }
    }

    private async Task<CommandResult> RestartMachineAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var delay = ParseDelaySeconds(root);
        try
        {
            var args = $"/r /t {delay} /c \"Endpoint Monitor remote restart\"";
            using var p = Process.Start(new ProcessStartInfo("shutdown", args)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
            });
            p?.WaitForExit(30_000);
            await database.AppendAuditAsync("restart_machine", $"t={delay}", clientIp, cancellationToken).ConfigureAwait(false);
            var msg = delay == 0
                ? "Restart initiated immediately"
                : $"Restart initiated in {delay} seconds";
            return new CommandResult(true, "restart_machine", msg);
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "restart_machine", ex.Message);
        }
    }

    private async Task<CommandResult> ShutdownMachineAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var delay = ParseDelaySeconds(root);
        try
        {
            var args = $"/s /t {delay} /c \"Endpoint Monitor remote shutdown\"";
            using var p = Process.Start(new ProcessStartInfo("shutdown", args)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
            });
            p?.WaitForExit(30_000);
            await database.AppendAuditAsync("shutdown_machine", $"t={delay}", clientIp, cancellationToken).ConfigureAwait(false);
            var msg = delay == 0
                ? "Shutdown initiated immediately"
                : $"Shutdown initiated in {delay} seconds";
            return new CommandResult(true, "shutdown_machine", msg);
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "shutdown_machine", ex.Message);
        }
    }

    private async Task<CommandResult> SleepMachineAsync(string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("rundll32.exe", "powrprof.dll,SetSuspendState 0,1,0")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
            });
            p?.WaitForExit(60_000);
            await database.AppendAuditAsync("sleep_machine", "ok", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "sleep_machine", "Sleep initiated");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "sleep_machine", ex.Message);
        }
    }

    private async Task<CommandResult> CancelShutdownAsync(string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            using var p = Process.Start(new ProcessStartInfo("shutdown", "/a")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
            });
            p?.WaitForExit(30_000);
            var code = p?.ExitCode ?? 1;
            if (code != 0)
            {
                await database.AppendAuditAsync("cancel_shutdown", "failed", clientIp, cancellationToken).ConfigureAwait(false);
                return new CommandResult(false, "cancel_shutdown", "No pending shutdown to cancel");
            }

            await database.AppendAuditAsync("cancel_shutdown", "ok", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "cancel_shutdown", "Pending shutdown or restart cancelled");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "cancel_shutdown", ex.Message);
        }
    }

    private async Task<CommandResult> TurnOffDisplayAsync(string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            // P/Invoke: turn monitor off. Fallback if this fails on some setups: nircmd.exe monitor off (nircmd must be on PATH).
            NativeMethods.SendMonitorPowerOff();
            await database.AppendAuditAsync("turn_off_display", "ok", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "turn_off_display", "Display turned off");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "turn_off_display", ex.Message);
        }
    }

    private async Task<CommandResult> SetVolumeAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            var volume = 50;
            if (root.TryGetProperty("volume", out var volEl) && volEl.ValueKind == JsonValueKind.Number)
                volume = volEl.GetInt32();
            volume = Math.Clamp(volume, 0, 100);

            if (!VolumeNativeMethods.TrySetMasterVolumePercent(volume))
                return new CommandResult(false, "set_volume", "Could not set system volume (audio endpoint unavailable).");

            await database.AppendAuditAsync("set_volume", $"v={volume}", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "set_volume", $"Volume set to {volume}%");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "set_volume", ex.Message);
        }
    }

    private async Task<CommandResult> ToggleMuteAsync(string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            VolumeNativeMethods.PressVolumeMuteKey();
            await database.AppendAuditAsync("toggle_mute", "ok", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "toggle_mute", "Mute toggled");
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "toggle_mute", ex.Message);
        }
    }

    /// <summary>
    /// Captures the virtual screen (all monitors), scales to a max dimension for WebSocket payload size,
    /// and returns PNG as base64 in <c>data</c>. May be blank when the service runs in session 0 without desktop access.
    /// </summary>
    private async Task<CommandResult> CaptureDesktopScreenshotAsync(string? clientIp, CancellationToken cancellationToken)
    {
        try
        {
            var data = await Task.Run(DesktopScreenshot.CaptureScaledPngData, cancellationToken).ConfigureAwait(false);
            await database.AppendAuditAsync("capture_desktop_screenshot", "ok", clientIp, cancellationToken).ConfigureAwait(false);
            return new CommandResult(true, "capture_desktop_screenshot", "Screenshot captured", data);
        }
        catch (Exception ex)
        {
            return new CommandResult(false, "capture_desktop_screenshot", ex.Message);
        }
    }

    private static void RunNetsh(string arguments)
    {
        using var p = Process.Start(new ProcessStartInfo("netsh", arguments)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        });
        p?.WaitForExit(30_000);
    }
}

internal static class DesktopScreenshot
{
    private const int MaxDimension = 1920;

    public static JsonElement CaptureScaledPngData()
    {
        var bounds = SystemInformation.VirtualScreen;
        var sw = bounds.Width;
        var sh = bounds.Height;
        if (sw <= 0 || sh <= 0)
            throw new InvalidOperationException("invalid_virtual_screen_bounds");

        var scale = 1.0;
        if (sw > MaxDimension || sh > MaxDimension)
            scale = Math.Min((double)MaxDimension / sw, (double)MaxDimension / sh);
        var tw = Math.Max(1, (int)Math.Round(sw * scale));
        var th = Math.Max(1, (int)Math.Round(sh * scale));

        using var output = new Bitmap(tw, th, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(output))
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            using var full = new Bitmap(sw, sh, PixelFormat.Format32bppArgb);
            using (var gFull = Graphics.FromImage(full))
            {
                gFull.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, full.Size, CopyPixelOperation.SourceCopy);
            }

            g.DrawImage(full, 0, 0, tw, th);
        }

        using var ms = new MemoryStream();
        output.Save(ms, ImageFormat.Png);
        return JsonSerializer.SerializeToElement(new
        {
            imageBase64 = Convert.ToBase64String(ms.ToArray()),
            width = tw,
            height = th,
            sourceWidth = sw,
            sourceHeight = sh
        }, AppJson.Options);
    }
}

internal static class NativeMethods
{
    private const uint ProcessSuspendResume = 0x0800;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint desiredAccess, bool inheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("ntdll.dll")]
    public static extern uint NtSuspendProcess(IntPtr processHandle);

    [DllImport("ntdll.dll")]
    public static extern uint NtResumeProcess(IntPtr processHandle);

    public static bool TryOpenProcess(int pid, out IntPtr handle)
    {
        handle = OpenProcess(ProcessSuspendResume, false, pid);
        return handle != IntPtr.Zero;
    }

    private const int WmSyscommand = 0x0112;
    private const int ScMonitorpower = 0xF170;

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    /// <summary>Broadcast SC_MONITORPOWER 2 to turn displays off.</summary>
    public static void SendMonitorPowerOff()
    {
        var hwndBroadcast = (IntPtr)0xffff;
        SendMessage(hwndBroadcast, WmSyscommand, (IntPtr)ScMonitorpower, (IntPtr)2);
    }
}

/// <summary>Default render endpoint master volume via Core Audio (vtable-accurate COM).</summary>
internal static class VolumeNativeMethods
{
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    private const byte VK_VOLUME_MUTE = 0xAD;
    private const uint KEYEVENTF_KEYUP = 0x0002;

    public static void PressVolumeMuteKey()
    {
        keybd_event(VK_VOLUME_MUTE, 0, 0, UIntPtr.Zero);
        keybd_event(VK_VOLUME_MUTE, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static bool TrySetMasterVolumePercent(int percent)
    {
        percent = Math.Clamp(percent, 0, 100);
        IMMDeviceEnumerator? deviceEnum = null;
        IMMDevice? device = null;
        IAudioEndpointVolume? vol = null;
        try
        {
            deviceEnum = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            device = deviceEnum.GetDefaultAudioEndpoint(MMDataFlow.Render, MMRole.Console);
            var iid = typeof(IAudioEndpointVolume).GUID;
            device.Activate(ref iid, (uint)CLSCTX_ALL, IntPtr.Zero, out var activated);
            vol = (IAudioEndpointVolume)activated;
            var ctx = Guid.Empty;
            vol.SetMasterVolumeLevelScalar(percent / 100f, ref ctx);
            return true;
        }
        catch
        {
            return false;
        }
        finally
        {
            if (vol != null) Marshal.ReleaseComObject(vol);
            if (device != null) Marshal.ReleaseComObject(device);
            if (deviceEnum != null) Marshal.ReleaseComObject(deviceEnum);
        }
    }

    private const int CLSCTX_ALL = 23;

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    private class MMDeviceEnumeratorComObject;

    [Guid("0BD7A1BE-7A1A-44DB-8397-C0C2C1F6F989"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceCollection;

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator
    {
        [PreserveSig]
        int EnumAudioEndpoints(
            MMDataFlow dataFlow,
            uint dwStateMask,
            [MarshalAs(UnmanagedType.Interface)] out IMMDeviceCollection? devices);

        [return: MarshalAs(UnmanagedType.Interface)]
        IMMDevice GetDefaultAudioEndpoint(MMDataFlow dataFlow, MMRole role);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice
    {
        void Activate(
            ref Guid iid,
            uint dwClsCtx,
            IntPtr pActivationParams,
            [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    }

    [Guid("657804FA-D6AD-4496-8A60-3527522914D0"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioEndpointVolumeCallback;

    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioEndpointVolume
    {
        void RegisterControlChangeNotify(
            [MarshalAs(UnmanagedType.Interface)] IAudioEndpointVolumeCallback pNotify);
        void UnregisterControlChangeNotify(
            [MarshalAs(UnmanagedType.Interface)] IAudioEndpointVolumeCallback pNotify);
        uint GetChannelCount();
        void SetMasterVolumeLevel(float fLevelDB, ref Guid pguidEventContext);
        void SetMasterVolumeLevelScalar(float fLevel, ref Guid pguidEventContext);
        void GetMasterVolumeLevel(out float pfLevelDB);
        void GetMasterVolumeLevelScalar(out float pfLevel);
        void SetChannelVolumeLevel(uint nChannel, float fLevelDB, ref Guid pguidEventContext);
        void SetChannelVolumeLevelScalar(uint nChannel, float fLevel, ref Guid pguidEventContext);
        void GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
        float GetChannelVolumeLevelScalar(uint nChannel);
        void SetMute(int bMute, ref Guid pguidEventContext);
        int GetMute();
        void GetVolumeStepInfo(out uint pnStep, out uint pnStepCount);
        void VolumeStepUp(ref Guid pguidEventContext);
        void VolumeStepDown(ref Guid pguidEventContext);
        void QueryHardwareSupport(out uint pdwHardwareSupportMask);
        void GetVolumeRange(out float pflVolumeMindB, out float pflVolumeMaxdB, out float pflVolumeIncrementdB);
    }

    private enum MMDataFlow { Render, Capture, All }
    private enum MMRole { Console, Multimedia, Communications }
}
