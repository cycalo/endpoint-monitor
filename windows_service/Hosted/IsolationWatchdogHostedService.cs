using EndpointMonitorService.Services;

namespace EndpointMonitorService.Hosted;

/// <summary>
/// Reconciles isolation state on startup and re-arms the 90s watchdog when the host is isolated.
/// </summary>
public sealed class IsolationWatchdogHostedService(
    ILogger<IsolationWatchdogHostedService> logger,
    FirewallIsolationService isolation) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await isolation.ReconcileAsync(stoppingToken).ConfigureAwait(false);
            if (await isolation.IsLiveIsolatedAsync(stoppingToken).ConfigureAwait(false))
                isolation.ArmWatchdog();
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Isolation reconcile on startup failed");
        }

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            // shutdown
        }
    }
}
