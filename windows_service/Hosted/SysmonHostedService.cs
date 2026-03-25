using EndpointMonitorService.Sysmon;

namespace EndpointMonitorService.Hosted;

public sealed class SysmonHostedService(
    ILogger<SysmonHostedService> logger,
    SysmonIngestService ingest,
    SysmonInstaller sysmonInstaller) : BackgroundService
{
    public override async Task StartAsync(CancellationToken cancellationToken)
    {
        await sysmonInstaller.EnsureInstalledAsync(cancellationToken).ConfigureAwait(false);
        await base.StartAsync(cancellationToken).ConfigureAwait(false);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await ingest.BackfillLast24HoursAsync(stoppingToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Sysmon backfill failed");
        }

        ingest.StartWatcher(stoppingToken);

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
