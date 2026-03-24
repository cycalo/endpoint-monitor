namespace EndpointMonitorService.Hosted;

public sealed class SysmonHostedService(
    ILogger<SysmonHostedService> logger,
    Sysmon.SysmonIngestService ingest) : BackgroundService
{
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
