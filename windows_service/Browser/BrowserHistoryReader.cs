using Microsoft.Data.Sqlite;
using EndpointMonitorService.Models;

namespace EndpointMonitorService.Browser;

public sealed class BrowserHistoryReader(ILogger<BrowserHistoryReader> logger)
{
    public Task<IReadOnlyList<BrowserHistoryEntry>> ReadAsync(string browser, CancellationToken cancellationToken)
    {
        browser = browser.ToLowerInvariant();
        return browser switch
        {
            "chrome" => ReadChromeEdgeAsync(true, cancellationToken),
            "edge" => ReadChromeEdgeAsync(false, cancellationToken),
            "firefox" => ReadFirefoxAsync(cancellationToken),
            "all" => ReadAllAsync(cancellationToken),
            _ => ReadAllAsync(cancellationToken)
        };
    }

    private async Task<IReadOnlyList<BrowserHistoryEntry>> ReadAllAsync(CancellationToken cancellationToken)
    {
        var a = await ReadChromeEdgeAsync(true, cancellationToken).ConfigureAwait(false);
        var b = await ReadChromeEdgeAsync(false, cancellationToken).ConfigureAwait(false);
        var c = await ReadFirefoxAsync(cancellationToken).ConfigureAwait(false);
        return a.Concat(b).Concat(c).OrderByDescending(x => x.VisitTime).Take(500).ToList();
    }

    private async Task<IReadOnlyList<BrowserHistoryEntry>> ReadChromeEdgeAsync(bool chrome, CancellationToken cancellationToken)
    {
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var path = chrome
            ? Path.Combine(local, @"Google\Chrome\User Data\Default\History")
            : Path.Combine(local, @"Microsoft\Edge\User Data\Default\History");
        return await ReadChromeStyleAsync(path, chrome ? "chrome" : "edge", cancellationToken).ConfigureAwait(false);
    }

    private async Task<IReadOnlyList<BrowserHistoryEntry>> ReadChromeStyleAsync(string historyPath, string browserName, CancellationToken cancellationToken)
    {
        var list = new List<BrowserHistoryEntry>();
        if (!File.Exists(historyPath))
            return list;

        var temp = Path.Combine(Path.GetTempPath(), $"em_hist_{browserName}_{Guid.NewGuid():N}.db");
        try
        {
            File.Copy(historyPath, temp, overwrite: true);
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Could not copy history {Path}", historyPath);
            return list;
        }

        try
        {
            await using var conn = new SqliteConnection($"Data Source={temp}");
            await conn.OpenAsync(cancellationToken).ConfigureAwait(false);
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = """
                SELECT url, title, visit_count,
                       datetime(last_visit_time/1000000-11644473600,'unixepoch') as visit_time
                FROM urls
                ORDER BY last_visit_time DESC
                LIMIT 500
                """;
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                list.Add(new BrowserHistoryEntry
                {
                    Browser = browserName,
                    Url = reader.GetString(0),
                    Title = reader.IsDBNull(1) ? "" : reader.GetString(1),
                    VisitCount = reader.GetInt32(2),
                    VisitTime = reader.IsDBNull(3) ? "" : reader.GetString(3)
                });
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Read Chrome-style history failed");
        }
        finally
        {
            try { File.Delete(temp); } catch { /* ignore */ }
        }

        return list;
    }

    private async Task<IReadOnlyList<BrowserHistoryEntry>> ReadFirefoxAsync(CancellationToken cancellationToken)
    {
        var list = new List<BrowserHistoryEntry>();
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var ini = Path.Combine(appData, @"Mozilla\Firefox\profiles.ini");
        if (!File.Exists(ini))
            return list;

        string? profilePath = null;
        foreach (var line in await File.ReadAllLinesAsync(ini, cancellationToken).ConfigureAwait(false))
        {
            if (line.StartsWith("Path=", StringComparison.OrdinalIgnoreCase))
            {
                var rel = line["Path=".Length..].Trim();
                profilePath = Path.Combine(appData, "Mozilla", "Firefox", rel.Replace('/', Path.DirectorySeparatorChar));
                break;
            }
        }

        if (profilePath == null)
            return list;

        var places = Path.Combine(profilePath, "places.sqlite");
        if (!File.Exists(places))
            return list;

        var temp = Path.Combine(Path.GetTempPath(), $"em_ff_{Guid.NewGuid():N}.db");
        try
        {
            File.Copy(places, temp, overwrite: true);
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Could not copy Firefox places");
            return list;
        }

        try
        {
            await using var conn = new SqliteConnection($"Data Source={temp}");
            await conn.OpenAsync(cancellationToken).ConfigureAwait(false);
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = """
                SELECT p.url, p.title, p.visit_count, h.visit_date
                FROM moz_places p
                JOIN moz_historyvisits h ON p.id = h.place_id
                ORDER BY h.visit_date DESC
                LIMIT 500
                """;
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                var vd = reader.GetInt64(3);
                var dt = DateTimeOffset.FromUnixTimeMilliseconds(vd / 1000).UtcDateTime.ToString("O");
                list.Add(new BrowserHistoryEntry
                {
                    Browser = "firefox",
                    Url = reader.GetString(0),
                    Title = reader.IsDBNull(1) ? "" : reader.GetString(1),
                    VisitCount = reader.GetInt32(2),
                    VisitTime = dt
                });
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Read Firefox history failed");
        }
        finally
        {
            try { File.Delete(temp); } catch { /* ignore */ }
        }

        return list;
    }
}
