using EndpointMonitorService.Commands;

namespace EndpointMonitorService.Hosted;

public sealed class FirewallBlockExpiryHostedService(
    ILogger<FirewallBlockExpiryHostedService> logger,
    ResponseCommandService commandService) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(60));
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken).ConfigureAwait(false))
            {
                try
                {
                    await commandService.PurgeExpiredFirewallBlocksAsync(stoppingToken).ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Firewall expiry purge failed");
                }
            }
        }
        catch (OperationCanceledException)
        {
            // shutdown
        }
    }
}
