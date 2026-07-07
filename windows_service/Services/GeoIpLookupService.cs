using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using MaxMind.GeoIP2;
using MaxMind.GeoIP2.Exceptions;

namespace EndpointMonitorService.Services;

public readonly record struct GeoIpResult(
    string CountryCode,
    string CountryName,
    string City,
    string Org)
{
    public static GeoIpResult Empty { get; } = new("", "", "", "");
}

/// <summary>
/// GeoLite2-City lookups with per-IP caching. Database path: working directory first, then app base directory.
/// </summary>
public sealed class GeoIpLookupService : IDisposable
{
    private readonly ILogger<GeoIpLookupService> _logger;
    private readonly DatabaseReader? _reader;
    private readonly ConcurrentDictionary<string, GeoIpResult> _cache = new(StringComparer.Ordinal);
    private const int MaxCacheEntries = 8192;

    public GeoIpLookupService(ILogger<GeoIpLookupService> logger)
    {
        _logger = logger;
        var (path, searched) = FindDatabasePath();
        if (path == null)
        {
            _logger.LogWarning(
                "GeoLite2-City.mmdb not found; geolocation disabled. Checked: {SearchedPaths}",
                string.Join(" | ", searched));
            return;
        }

        try
        {
            _reader = new DatabaseReader(path);
            _logger.LogInformation("GeoLite2-City database loaded from {Path}", path);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to open GeoLite2-City database at {Path}", path);
        }
    }

    private static (string? Path, IReadOnlyList<string> Searched) FindDatabasePath()
    {
        var searched = new List<string>();
        var fileName = "GeoLite2-City.mmdb";

        var envPath = Environment.GetEnvironmentVariable("GEOLITE2_CITY_DB_PATH");
        if (!string.IsNullOrWhiteSpace(envPath))
        {
            try
            {
                var full = Path.GetFullPath(envPath.Trim());
                searched.Add(full);
                if (File.Exists(full)) return (full, searched);
            }
            catch
            {
                // ignore invalid env path
            }
        }

        foreach (var dir in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
        {
            try
            {
                var p = Path.Combine(dir, fileName);
                searched.Add(p);
                if (File.Exists(p)) return (p, searched);
            }
            catch
            {
                // ignore invalid paths
            }
        }

        return (null, searched);
    }

    public GeoIpResult Lookup(string? ipString)
    {
        if (_reader == null || string.IsNullOrWhiteSpace(ipString)) return GeoIpResult.Empty;
        var key = ipString.Trim();
        if (!IPAddress.TryParse(key, out var ip)) return GeoIpResult.Empty;
        if (IsPrivateOrLocal(ip)) return GeoIpResult.Empty;

        if (_cache.Count >= MaxCacheEntries && !_cache.ContainsKey(key))
            _cache.Clear();

        return _cache.GetOrAdd(key, LookupUncached);
    }

    private GeoIpResult LookupUncached(string ipString)
    {
        try
        {
            var r = _reader!.City(ipString);
            var org = FirstNonEmpty(
                r.Traits?.AutonomousSystemOrganization,
                r.Traits?.Isp,
                r.Traits?.Organization);
            return new GeoIpResult(
                r.Country?.IsoCode ?? "",
                r.Country?.Name ?? "",
                r.City?.Name ?? "",
                org);
        }
        catch (AddressNotFoundException)
        {
            return GeoIpResult.Empty;
        }
        catch (GeoIP2Exception ex)
        {
            _logger.LogDebug(ex, "GeoIP2 error for {Ip}", ipString);
            return GeoIpResult.Empty;
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "GeoIP lookup failed for {Ip}", ipString);
            return GeoIpResult.Empty;
        }
    }

    private static string FirstNonEmpty(params string?[] values)
    {
        foreach (var v in values)
        {
            if (!string.IsNullOrWhiteSpace(v)) return v.Trim();
        }

        return "";
    }

    /// <summary>
    /// Skips RFC1918, loopback, link-local, multicast, and typical non-public ranges.
    /// </summary>
    public static bool IsPrivateOrLocal(IPAddress ip)
    {
        if (IPAddress.IsLoopback(ip)) return true;

        if (ip.AddressFamily == AddressFamily.InterNetwork)
        {
            var b = ip.GetAddressBytes();
            if (b[0] == 10) return true;
            if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
            if (b[0] == 192 && b[1] == 168) return true;
            if (b[0] == 127) return true;
            if (b[0] == 169 && b[1] == 254) return true;
            if (b[0] == 0) return true;
            if (b[0] >= 224) return true;
            return false;
        }

        if (ip.AddressFamily == AddressFamily.InterNetworkV6)
        {
            if (ip.IsIPv6LinkLocal) return true;
            if (ip.IsIPv4MappedToIPv6) return IsPrivateOrLocal(ip.MapToIPv4());

            var bytes = ip.GetAddressBytes();
            if (bytes[0] == 0xfc || bytes[0] == 0xfd) return true;
            return false;
        }

        return true;
    }

    public void Dispose() => _reader?.Dispose();
}
