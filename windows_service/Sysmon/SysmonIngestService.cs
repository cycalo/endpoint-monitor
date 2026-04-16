using System.Diagnostics.Eventing.Reader;
using System.Text.Json;
using EndpointMonitorService.Alerts;
using EndpointMonitorService.Database;
using EndpointMonitorService.Models;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Sysmon;

public sealed class SysmonIngestService(
    ILogger<SysmonIngestService> logger,
    AppDatabase database,
    WebSocketConnectionManager ws,
    AlertEngine alertEngine)
{
    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public async Task BackfillLast24HoursAsync(CancellationToken cancellationToken)
    {
        const string logName = "Microsoft-Windows-Sysmon/Operational";
        const string xpath =
            "*[System[(EventID=1 or EventID=3 or EventID=5 or EventID=22) and TimeCreated[timediff(@SystemTime) <= 86400000]]]";
        try
        {
            using var log = new EventLogReader(new EventLogQuery(logName, PathType.LogName, xpath));
            var count = 0;
            for (var rec = log.ReadEvent(); rec != null; rec = log.ReadEvent())
            {
                cancellationToken.ThrowIfCancellationRequested();
                using (rec)
                {
                    var ev = SysmonEventParser.TryParse(rec);
                    if (ev != null)
                    {
                        await IngestParsedEventAsync(ev, cancellationToken, broadcast: false, evaluateAlerts: false).ConfigureAwait(false);
                    }
                }
                count++;
                if (count > 100000)
                    break;
            }

            logger.LogInformation("Sysmon backfill inserted {Count} records (24h window)", count);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Sysmon backfill failed — is Sysmon installed?");
        }
    }

    public void StartWatcher(CancellationToken cancellationToken)
    {
        const string logName = "Microsoft-Windows-Sysmon/Operational";
        try
        {
            var query = new EventLogQuery(logName, PathType.LogName);
            var watcher = new EventLogWatcher(query);
            watcher.EventRecordWritten += (_, args) =>
            {
                if (args.EventRecord == null)
                    return;
                
                SysmonEvent? ev = null;
                try
                {
                    using (var rec = args.EventRecord)
                    {
                        ev = SysmonEventParser.TryParse(rec);
                    }
                }
                catch (Exception ex)
                {
                    logger.LogDebug(ex, "Sysmon event parse failed");
                }

                if (ev == null)
                    return;

                _ = Task.Run(async () =>
                {
                    try
                    {
                        await IngestParsedEventAsync(ev, cancellationToken, broadcast: true, evaluateAlerts: true).ConfigureAwait(false);
                    }
                    catch (Exception ex)
                    {
                        logger.LogDebug(ex, "Sysmon watcher ingest failed");
                    }
                }, cancellationToken);
            };

            watcher.Enabled = true;
            logger.LogInformation("Sysmon EventLogWatcher enabled");
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Sysmon watcher failed to start");
        }
    }

    public async Task IngestParsedEventAsync(
        SysmonEvent ev,
        CancellationToken cancellationToken,
        bool broadcast = true,
        bool evaluateAlerts = true)
    {
        var row = new SysmonEventRow
        {
            EventId = ev.EventId,
            Timestamp = ev.Timestamp,
            Type = ev.Type,
            Pid = ev.Pid,
            ProcessName = ev.ProcessName,
            CommandLine = ev.CommandLine,
            ParentPid = ev.ParentPid,
            RemoteAddress = ev.RemoteAddress,
            RemotePort = ev.RemotePort,
            DnsQuery = ev.DnsQuery,
            RawXml = ev.RawXml
        };

        await database.InsertSysmonAsync(row, cancellationToken).ConfigureAwait(false);

        if (broadcast)
        {
            var payload = JsonSerializer.Serialize(new { type = "sysmon_event", data = ev }, Json);
            await ws.BroadcastAsync(System.Text.Encoding.UTF8.GetBytes(payload), cancellationToken).ConfigureAwait(false);
        }

        if (evaluateAlerts)
            await alertEngine.EvaluateAsync(ev, cancellationToken).ConfigureAwait(false);
    }
}
