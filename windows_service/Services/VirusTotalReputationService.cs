using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Services;

public sealed class VirusTotalReputationService(
    ILogger<VirusTotalReputationService> logger,
    IHttpClientFactory httpClientFactory,
    IOptions<VirusTotalOptions> options)
{
    private readonly ConcurrentDictionary<string, CacheEntry> _cache = new();

    private sealed record CacheEntry(string PayloadJson, DateTime ExpiresUtc);

    public async Task<JsonElement> CheckProcessExecutableAsync(int pid, CancellationToken cancellationToken)
    {
        var key = options.Value.ApiKey?.Trim() ?? "";
        if (string.IsNullOrEmpty(key))
        {
            return JsonSerializer.SerializeToElement(new
            {
                ok = false,
                error = "virustotal_not_configured"
            }, AppJson.Options);
        }

        string? path;
        try
        {
            using var p = System.Diagnostics.Process.GetProcessById(pid);
            path = p.MainModule?.FileName;
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "VT: could not open process {Pid}", pid);
            return JsonSerializer.SerializeToElement(new
            {
                ok = false,
                error = "process_unavailable"
            }, AppJson.Options);
        }

        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            return JsonSerializer.SerializeToElement(new
            {
                ok = false,
                error = "path_unreadable"
            }, AppJson.Options);
        }

        string sha256;
        await using (var fs = File.OpenRead(path))
        {
            var hash = await SHA256.HashDataAsync(fs, cancellationToken).ConfigureAwait(false);
            sha256 = Convert.ToHexString(hash).ToLowerInvariant();
        }

        var ttl = TimeSpan.FromHours(Math.Clamp(options.Value.CacheTtlHours, 1, 168));
        if (_cache.TryGetValue(sha256, out var cached) && cached.ExpiresUtc > DateTime.UtcNow)
        {
            using var cachedDoc = JsonDocument.Parse(cached.PayloadJson);
            return cachedDoc.RootElement.Clone();
        }

        var client = httpClientFactory.CreateClient("virustotal");
        using var req = new HttpRequestMessage(HttpMethod.Get, $"files/{sha256}");
        req.Headers.Add("x-apikey", key);

        HttpResponseMessage resp;
        try
        {
            resp = await client.SendAsync(req, cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "VT HTTP failed");
            return JsonSerializer.SerializeToElement(new
            {
                ok = false,
                error = "http_error"
            }, AppJson.Options);
        }

        if (resp.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            var notFound = JsonSerializer.SerializeToElement(new
            {
                ok = true,
                sha256,
                verdict = "unknown",
                malicious = 0,
                suspicious = 0,
                harmless = 0,
                undetected = 0,
                permalink = (string?)null
            }, AppJson.Options);
            _cache[sha256] = new CacheEntry(JsonSerializer.Serialize(notFound), DateTime.UtcNow + ttl);
            return notFound;
        }

        if ((int)resp.StatusCode == 429)
        {
            return JsonSerializer.SerializeToElement(new
            {
                ok = false,
                error = "rate_limited"
            }, AppJson.Options);
        }

        if (!resp.IsSuccessStatusCode)
        {
            return JsonSerializer.SerializeToElement(new
            {
                ok = false,
                error = $"http_{(int)resp.StatusCode}"
            }, AppJson.Options);
        }

        await using var stream = await resp.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
        var root = doc.RootElement;
        var data = root.TryGetProperty("data", out var d) ? d : root;
        var attrs = data.TryGetProperty("attributes", out var a) ? a : default;
        var stats = attrs.ValueKind == JsonValueKind.Object && attrs.TryGetProperty("last_analysis_stats", out var s)
            ? s
            : default;

        int GetStat(string name) =>
            stats.ValueKind == JsonValueKind.Object &&
            stats.TryGetProperty(name, out var el) &&
            el.TryGetInt32(out var v)
                ? v
                : 0;

        var malicious = GetStat("malicious");
        var suspicious = GetStat("suspicious");
        var harmless = GetStat("harmless");
        var undetected = GetStat("undetected");

        string verdict;
        if (malicious > 0) verdict = "malicious";
        else if (suspicious > 0) verdict = "suspicious";
        else if (harmless + undetected > 0) verdict = "clean_or_unknown";
        else verdict = "unknown";

        string? permalink = null;
        if (data.TryGetProperty("links", out var links) &&
            links.TryGetProperty("self", out var self))
            permalink = self.GetString();

        var payload = JsonSerializer.SerializeToElement(new
        {
            ok = true,
            sha256,
            path,
            verdict,
            malicious,
            suspicious,
            harmless,
            undetected,
            permalink
        }, AppJson.Options);

        _cache[sha256] = new CacheEntry(JsonSerializer.Serialize(payload), DateTime.UtcNow + ttl);
        return payload;
    }
}
