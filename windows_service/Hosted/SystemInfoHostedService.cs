using System.Text.Json;
using EndpointMonitorService.Collectors;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Hosted;

public sealed class SystemInfoHostedService(
    ILogger<SystemInfoHostedService> logger,
    WebSocketConnectionManager ws,
    CollectorSnapshotCache snapshots,
    SystemInfoCollector systemInfoCollector,
    Database.AppDatabase database,
    IOptionsMonitor<MonitoringOptions> options) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var cfg = options.CurrentValue;
            var interval = TimeSpan.FromSeconds(Math.Clamp(cfg.SystemInfoIntervalSeconds, 5, 300));
            var idleInterval = TimeSpan.FromSeconds(Math.Clamp(cfg.IdleIntervalSeconds, 5, 600));

            if (ws.ClientCount == 0)
            {
                try
                {
                    await Task.Delay(idleInterval, stoppingToken).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    break;
                }

                continue;
            }

            try
            {
                var snap = snapshots.GetSnapshot();
                var info = systemInfoCollector.Collect(cacheSeconds: cfg.SystemInfoCacheSeconds);
                info.ProcessCount = snap.Processes.Count;
                info.NetworkConnectionCount = snap.Network.Count;

                try
                {
                    info.EventsTodayCount = await database.CountEventsSinceAsync(DateTime.UtcNow.Date, stoppingToken).ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    logger.LogDebug(ex, "Events count failed");
                }

                var json = JsonSerializer.Serialize(new { type = "system_info", data = info }, AppJson.Options);
                await ws.BroadcastAsync(System.Text.Encoding.UTF8.GetBytes(json), stoppingToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "System info broadcast failed");
            }

            try
            {
                await Task.Delay(interval, stoppingToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }
}
