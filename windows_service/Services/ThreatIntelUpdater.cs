using System.Net;
using System.Text.RegularExpressions;
using EndpointMonitorService.Database;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Services;

public sealed class ThreatIntelUpdater(
    ILogger<ThreatIntelUpdater> logger,
    AppDatabase database,
    IHttpClientFactory httpClientFactory,
    IOptionsMonitor<ThreatIntelOptions> optionsMonitor)
{
    private static readonly Regex IpLine = new(
        @"^\s*(\d{1,3}(?:\.\d{1,3}){3})\s*$",
        RegexOptions.Compiled);

    public DateTimeOffset? LastSuccessfulRunUtc { get; private set; }
    public int LastEntriesWritten { get; private set; }
    public string? LastError { get; private set; }

    public async Task RunUpdateAsync(CancellationToken cancellationToken)
    {
        var opt = optionsMonitor.CurrentValue;
        LastError = null;
        if (!opt.Enabled)
        {
            LastError = "disabled";
            return;
        }

        var client = httpClientFactory.CreateClient("threat_intel");
        var ttlDays = Math.Clamp(opt.FeedEntryTtlDays, 1, 365);
        var expires = DateTime.UtcNow.AddDays(ttlDays).ToString("O");
        var written = 0;

        foreach (var kv in opt.Feeds)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var source = kv.Key;
            var url = kv.Value;
            if (string.IsNullOrWhiteSpace(url)) continue;

            try
            {
                var text = await client.GetStringAsync(url, cancellationToken).ConfigureAwait(false);
                foreach (var line in text.Split('\n'))
                {
                    var t = line.Trim();
                    if (t.Length == 0 || t.StartsWith('#')) continue;
                    var m = IpLine.Match(t);
                    if (!m.Success) continue;
                    if (!IPAddress.TryParse(m.Groups[1].Value, out var ip))
                        continue;
                    var s = ip.ToString();
                    await database.UpsertThreatIntelIpAsync(s, source, "malicious", expires, cancellationToken).ConfigureAwait(false);
                    written++;
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Threat intel feed {Source} failed", source);
                LastError = $"{source}: {ex.Message}";
            }
        }

        var removed = await database.DeleteExpiredBadIpsAsync(cancellationToken).ConfigureAwait(false);
        await database.PruneAlertHistoryAsync(TimeSpan.FromDays(14), cancellationToken).ConfigureAwait(false);
        logger.LogInformation("Threat intel update: upserted {Written}, removed expired {Removed}", written, removed);

        LastEntriesWritten = written;
        LastSuccessfulRunUtc = DateTimeOffset.UtcNow;
    }
}
