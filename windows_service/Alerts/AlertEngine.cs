using System.Text.Json;
using EndpointMonitorService.Database;
using EndpointMonitorService.Models;

namespace EndpointMonitorService.Alerts;

public sealed class AlertEngine(
    ILogger<AlertEngine> logger,
    AppDatabase database,
    Services.WebSocketConnectionManager ws)
{
    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public async Task EvaluateAsync(SysmonEvent ev, CancellationToken cancellationToken)
    {
        try
        {
            var alerts = new List<Alert>();

            if (ev.Type == "NetworkConnect" && !string.IsNullOrEmpty(ev.RemoteAddress))
            {
                var badMeta = await database.GetBadIpRowAsync(ev.RemoteAddress, cancellationToken).ConfigureAwait(false);
                if (badMeta != null)
                {
                    var cat = string.IsNullOrEmpty(badMeta.Category) ? "listed" : badMeta.Category;
                    var src = string.IsNullOrEmpty(badMeta.Source) ? "intel" : badMeta.Source;
                    alerts.Add(MakeAlert("high", "threat_intel_connection",
                        $"Threat-listed IP {ev.RemoteAddress} ({cat} · {src}). Consider blocking outbound traffic to this host.",
                        ev.Pid));
                }

                if (IsBrowserProcess(ev.ProcessName) && ev.RemotePort is > 0 and not (80 or 443 or 8080 or 8443))
                {
                    alerts.Add(MakeAlert("medium", "suspicious_connection",
                        $"Browser {ev.ProcessName} connected to non-HTTP port {ev.RemotePort}", ev.Pid));
                }
            }

            if (ev.Type == "ProcessCreate")
            {
                if (ev.ParentPid is null or 0)
                    alerts.Add(MakeAlert("low", "new_process", "Process with missing parent PID", ev.Pid));

                var flags = await database.GetFlaggedProcessNamesAsync(cancellationToken).ConfigureAwait(false);
                if (flags.Any(f => ev.ProcessName.Equals(f, StringComparison.OrdinalIgnoreCase)))
                {
                    alerts.Add(MakeAlert("high", "flagged_process", $"Flagged process started: {ev.ProcessName}", ev.Pid));
                }

                var cmd = ev.CommandLine ?? "";
                if (cmd.Contains("-enc", StringComparison.OrdinalIgnoreCase) ||
                    cmd.Contains("-encodedcommand", StringComparison.OrdinalIgnoreCase))
                {
                    alerts.Add(MakeAlert("high", "flagged_process", "Encoded PowerShell/cmd command line detected", ev.Pid));
                }
            }

            foreach (var a in alerts)
            {
                await database.AppendAlertHistoryAsync(a.Type, a.Timestamp, cancellationToken).ConfigureAwait(false);
                var payload = JsonSerializer.Serialize(new { type = "alert", data = a }, Json);
                await ws.BroadcastAsync(System.Text.Encoding.UTF8.GetBytes(payload), cancellationToken).ConfigureAwait(false);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "AlertEngine evaluation failed");
        }
    }

    private static bool IsBrowserProcess(string name)
    {
        var n = name.ToLowerInvariant();
        return n.Contains("chrome") || n.Contains("msedge") || n.Contains("firefox") || n.Contains("brave");
    }

    private static Alert MakeAlert(string severity, string type, string message, int pid)
    {
        return new Alert
        {
            Id = Guid.NewGuid().ToString("N"),
            Timestamp = DateTime.UtcNow.ToString("O"),
            Severity = severity,
            Type = type,
            Message = message,
            RelatedPid = pid
        };
    }
}
