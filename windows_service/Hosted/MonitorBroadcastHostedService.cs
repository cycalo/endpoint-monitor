using System.Text.Json;
using EndpointMonitorService.Collectors;
using EndpointMonitorService.Models;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Hosted;

public sealed class MonitorBroadcastHostedService(
    ILogger<MonitorBroadcastHostedService> logger,
    WebSocketConnectionManager ws,
    ProcessCollector processCollector,
    NetworkCollector networkCollector) : BackgroundService
{
    /// <summary>Interval between full process + network snapshots broadcast to all WebSocket clients (development plan: 5s).</summary>
    private static readonly TimeSpan BroadcastInterval = TimeSpan.FromSeconds(5);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                IReadOnlyList<ProcessInfo> processes;
                try
                {
                    processes = processCollector.Collect();
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Process collector failed");
                    processes = [];
                }

                IReadOnlyList<NetworkConnection> network;
                try
                {
                    network = networkCollector.Collect();
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Network collector failed");
                    network = [];
                }

                var pJson = JsonSerializer.Serialize(new { type = "processes", data = processes }, AppJson.Options);
                await ws.BroadcastAsync(System.Text.Encoding.UTF8.GetBytes(pJson), stoppingToken).ConfigureAwait(false);

                var nJson = JsonSerializer.Serialize(new { type = "network", data = network }, AppJson.Options);
                await ws.BroadcastAsync(System.Text.Encoding.UTF8.GetBytes(nJson), stoppingToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Broadcast loop error");
            }

            try
            {
                await Task.Delay(BroadcastInterval, stoppingToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }
}
