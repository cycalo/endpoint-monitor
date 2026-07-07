using System.Reflection;
using EndpointMonitorService.Options;
using EndpointMonitorService.Sysmon;

namespace EndpointMonitorService.Services;

public sealed record AgentDiagnostics(
    string Version,
    int HttpPort,
    bool UseHttps,
    int HttpsPort,
    int WebSocketClients,
    bool SysmonInstalled,
    bool ThreatIntelEnabled,
    string? ThreatIntelLastRunUtc,
    string? ThreatIntelLastError,
    int ThreatIntelEntryCount,
    string DataDirectory,
    bool RunningAsAdministrator,
    bool InteractiveSession);

public static class AgentDiagnosticsBuilder
{
    public static AgentDiagnostics Build(
        ServerOptions server,
        ThreatIntelOptions threatIntel,
        WebSocketConnectionManager ws,
        SysmonInstaller sysmon,
        ThreatIntelUpdater intel,
        int threatIntelEntryCount)
    {
        var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "0.0.0";
        var dataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "EndpointMonitor");

        return new AgentDiagnostics(
            version,
            server.Port,
            server.UseHttps,
            server.HttpsPort,
            ws.ClientCount,
            sysmon.IsSysmonInstalled(),
            threatIntel.Enabled,
            intel.LastSuccessfulRunUtc?.UtcDateTime.ToString("O"),
            string.IsNullOrEmpty(intel.LastError) ? null : intel.LastError,
            threatIntelEntryCount,
            dataDir,
            IsRunningAsAdministrator(),
            Environment.UserInteractive);
    }

    private static bool IsRunningAsAdministrator()
    {
        try
        {
            using var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
            var principal = new System.Security.Principal.WindowsPrincipal(identity);
            return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
        }
        catch
        {
            return false;
        }
    }
}
