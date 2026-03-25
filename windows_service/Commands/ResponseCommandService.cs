using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using EndpointMonitorService.Database;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Commands;

public sealed class ResponseCommandService(
    ILogger<ResponseCommandService> logger,
    AppDatabase database,
    IOptions<ServerOptions> serverOptions,
    Browser.BrowserHistoryReader browserHistoryReader,
    Collectors.InstalledSoftwareCollector installedSoftwareCollector)
{
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
                "ack_alert" => await AckAlertAsync(root, cancellationToken).ConfigureAwait(false),
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

    private async Task<CommandResult> BlockIpAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var ip = root.GetProperty("ip").GetString() ?? "";
        var dir = root.TryGetProperty("direction", out var d) ? d.GetString() ?? "outbound" : "outbound";
        var ruleName = $"EM_BLOCK_{ip.Replace('.', '_')}";
        var args = $"advfirewall firewall add rule name=\"{ruleName}\" dir=out action=block remoteip={ip}";
        if (dir.Equals("inbound", StringComparison.OrdinalIgnoreCase))
            args = $"advfirewall firewall add rule name=\"{ruleName}_in\" dir=in action=block remoteip={ip}";

        RunNetsh(args);
        await database.AddFirewallBlockAsync(ip, dir, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("block_ip", ip, clientIp, cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "block_ip", "ok");
    }

    private async Task<CommandResult> UnblockIpAsync(JsonElement root, string? clientIp, CancellationToken cancellationToken)
    {
        var ip = root.GetProperty("ip").GetString() ?? "";
        var ruleName = $"EM_BLOCK_{ip.Replace('.', '_')}";
        RunNetsh($"advfirewall firewall delete rule name=\"{ruleName}\"");
        RunNetsh($"advfirewall firewall delete rule name=\"{ruleName}_in\"");
        await database.RemoveFirewallBlockAsync(ip, cancellationToken).ConfigureAwait(false);
        await database.AppendAuditAsync("unblock_ip", ip, clientIp, cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "unblock_ip", "ok");
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
        return new CommandResult(true, "unisolate_machine", "ok");
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

    private async Task<CommandResult> AckAlertAsync(JsonElement root, CancellationToken cancellationToken)
    {
        var id = root.GetProperty("id").GetString() ?? "";
        await database.AckAlertAsync(id, cancellationToken).ConfigureAwait(false);
        return new CommandResult(true, "ack_alert", "ok");
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
}
