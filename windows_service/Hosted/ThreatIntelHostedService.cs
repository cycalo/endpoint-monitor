using System.Text;
using System.Text.Json;
using EndpointMonitorService.Database;
using EndpointMonitorService.Models;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;
using EndpointMonitorService.Services;
using EndpointMonitorService.Collectors;

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

public sealed class InstalledSoftwareDetectionHostedService(
    ILogger<InstalledSoftwareDetectionHostedService> logger,
    InstalledSoftwareCollector collector,
    AppDatabase database,
    WebSocketConnectionManager ws,
    IOptionsMonitor<SoftwareMonitoringOptions> options)
    : BackgroundService
{
    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Delay(TimeSpan.FromSeconds(20), stoppingToken).ConfigureAwait(false);
        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var cfg = options.CurrentValue;
                if (cfg.Enabled)
                {
                    try
                    {
                        await CheckOnceAsync(cfg, stoppingToken).ConfigureAwait(false);
                    }
                    catch (Exception ex)
                    {
                        logger.LogWarning(ex, "Installed software scheduled check failed");
                    }
                }

                var interval = TimeSpan.FromMinutes(Math.Clamp(cfg.InstallCheckIntervalMinutes, 1, 1440));
                await Task.Delay(interval, stoppingToken).ConfigureAwait(false);
            }
        }
        catch (OperationCanceledException)
        {
            // shutdown
        }
    }

    private async Task CheckOnceAsync(SoftwareMonitoringOptions cfg, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var nowIso = now.ToString("O");
        var software = await collector.CollectAsync(cancellationToken).ConfigureAwait(false);
        var known = await database.GetInstalledSoftwareStateMapAsync(cancellationToken).ConfigureAwait(false);
        var firstBaseline = known.Count == 0;

        var newInstalls = new List<InstalledSoftwareItem>();
        foreach (var s in software)
        {
            var signature = BuildSignature(s);
            if (string.IsNullOrWhiteSpace(signature))
                continue;

            if (!firstBaseline && !known.ContainsKey(signature))
                newInstalls.Add(s);

            var firstSeen = known.TryGetValue(signature, out var existing)
                ? existing.FirstSeenAt
                : nowIso;

            await database.UpsertInstalledSoftwareStateAsync(new InstalledSoftwareStateRow
            {
                Signature = signature,
                Name = s.Name.Trim(),
                Version = s.Version.Trim(),
                Vendor = s.Vendor.Trim(),
                FirstSeenAt = firstSeen,
                LastSeenAt = nowIso
            }, cancellationToken).ConfigureAwait(false);
        }

        if (firstBaseline)
        {
            logger.LogInformation("Installed software baseline seeded with {Count} entries", software.Count);
            return;
        }

        var take = Math.Clamp(cfg.MaxAlertsPerRun, 1, 200);
        foreach (var s in newInstalls.Take(take))
        {
            var alert = new Alert
            {
                Id = Guid.NewGuid().ToString("N"),
                Timestamp = nowIso,
                Severity = "medium",
                Type = "software_install_detected",
                Message = BuildInstallMessage(s),
                RelatedPid = null
            };

            await database.AppendAlertHistoryAsync(alert.Type, alert.Timestamp, cancellationToken).ConfigureAwait(false);
            await database.AppendAuditAsync("software_install_detected", alert.Message, null, cancellationToken).ConfigureAwait(false);
            var payload = JsonSerializer.Serialize(new { type = "alert", data = alert }, Json);
            await ws.BroadcastAsync(Encoding.UTF8.GetBytes(payload), cancellationToken).ConfigureAwait(false);
        }

        if (newInstalls.Count > take)
        {
            logger.LogInformation("Detected {Count} new software entries; emitted {Emitted} alerts this run", newInstalls.Count, take);
        }
    }

    private static string BuildSignature(InstalledSoftwareItem s)
    {
        static string Norm(string? v) => (v ?? "").Trim().ToLowerInvariant();
        return string.Join("|",
            Norm(s.UninstallRegistrySubKey),
            Norm(s.Name),
            Norm(s.Version),
            Norm(s.Vendor),
            Norm(s.InstallLocation),
            Norm(s.InstallDate));
    }

    private static string BuildInstallMessage(InstalledSoftwareItem s)
    {
        var name = string.IsNullOrWhiteSpace(s.Name) ? "Unknown software" : s.Name.Trim();
        var version = string.IsNullOrWhiteSpace(s.Version) ? "" : $" {s.Version.Trim()}";
        var vendor = string.IsNullOrWhiteSpace(s.Vendor) ? "" : $" by {s.Vendor.Trim()}";
        return $"New software detected: {name}{version}{vendor}".Trim();
    }
}
