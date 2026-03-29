using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Hosted;

public sealed class ThreatIntelHostedService(
    ILogger<ThreatIntelHostedService> logger,
    ThreatIntelUpdater updater,
    IOptionsMonitor<ThreatIntelOptions> options)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Delay(TimeSpan.FromSeconds(15), stoppingToken).ConfigureAwait(false);
        var interval = TimeSpan.FromHours(Math.Clamp(options.CurrentValue.UpdateIntervalHours, 1, 168));
        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                if (options.CurrentValue.Enabled)
                {
                    try
                    {
                        await updater.RunUpdateAsync(stoppingToken).ConfigureAwait(false);
                    }
                    catch (Exception ex)
                    {
                        logger.LogWarning(ex, "Threat intel scheduled run failed");
                    }
                }
                await Task.Delay(interval, stoppingToken).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException)
        {
            // shutdown
        }
    }
}
