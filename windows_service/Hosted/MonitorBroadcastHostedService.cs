using System.Text.Json;
using EndpointMonitorService.Collectors;
using EndpointMonitorService.Models;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Hosted;

public sealed class MonitorBroadcastHostedService(
    ILogger<MonitorBroadcastHostedService> logger,
    WebSocketConnectionManager ws,
    CollectorSnapshotCache snapshots,
    IOptionsMonitor<MonitoringOptions> options) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var cfg = options.CurrentValue;
            var activeInterval = TimeSpan.FromSeconds(Math.Clamp(cfg.ActiveBroadcastIntervalSeconds, 2, 120));
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
                var pJson = JsonSerializer.Serialize(new { type = "processes", data = snap.Processes }, AppJson.Options);
                await ws.BroadcastAsync(System.Text.Encoding.UTF8.GetBytes(pJson), stoppingToken).ConfigureAwait(false);

                var nJson = JsonSerializer.Serialize(new { type = "network", data = snap.Network }, AppJson.Options);
                await ws.BroadcastAsync(System.Text.Encoding.UTF8.GetBytes(nJson), stoppingToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Broadcast loop error");
            }

            try
            {
                await Task.Delay(activeInterval, stoppingToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }
}
