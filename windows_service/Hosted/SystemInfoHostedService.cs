using System.Text.Json;
using EndpointMonitorService.Collectors;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Hosted;

public sealed class SystemInfoHostedService(
    ILogger<SystemInfoHostedService> logger,
    WebSocketConnectionManager ws,
    SystemInfoCollector systemInfoCollector,
    ProcessCollector processCollector,
    NetworkCollector networkCollector,
    Database.AppDatabase database) : BackgroundService
{
    /// <summary>Interval between system_info broadcasts (development plan: 10s; slower than process/network by design).</summary>
    private static readonly TimeSpan SystemInfoInterval = TimeSpan.FromSeconds(10);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var info = systemInfoCollector.Collect();
                try
                {
                    info.ProcessCount = processCollector.Collect().Count;
                }
                catch (Exception ex)
                {
                    logger.LogDebug(ex, "Process count failed");
                }

                try
                {
                    info.NetworkConnectionCount = networkCollector.Collect().Count;
                }
                catch (Exception ex)
                {
                    logger.LogDebug(ex, "Network count failed");
                }

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
                await Task.Delay(SystemInfoInterval, stoppingToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }
}
