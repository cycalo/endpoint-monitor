using EndpointMonitorService.Models;
using SQLite;

namespace EndpointMonitorService.Database;

public sealed class AppDatabase(ILogger<AppDatabase> logger)
{
    private SQLiteAsyncConnection? _db;

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EndpointMonitor");
        Directory.CreateDirectory(dir);
        var path = Path.Combine(dir, "endpoint_monitor.db");
        _db = new SQLiteAsyncConnection(path);
        await _db.CreateTableAsync<SysmonEventRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<FlaggedProcessRow>().ConfigureAwait(false);
        await TryAddFlaggedAddedAtColumnAsync().ConfigureAwait(false);
        await _db.CreateTableAsync<FirewallBlockRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<FirewallProcessBlockRow>().ConfigureAwait(false);
        await TryAddFirewallSourceProcessColumnAsync().ConfigureAwait(false);
        await TryAddFirewallRemotePortExpiresColumnsAsync().ConfigureAwait(false);
        await _db.CreateTableAsync<AuditLogRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<IsolationStateRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<BadIpRow>().ConfigureAwait(false);
        await TryMigrateBadIpColumnsAsync().ConfigureAwait(false);
        await _db.CreateTableAsync<AlertHistoryRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<AlertAckRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<InstalledSoftwareStateRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<DeviceAuthTokenRow>().ConfigureAwait(false);

        var iso = await _db.Table<IsolationStateRow>().FirstOrDefaultAsync().ConfigureAwait(false);
        if (iso == null)
            await _db.InsertAsync(new IsolationStateRow { Id = 1, IsIsolated = false }).ConfigureAwait(false);

        logger.LogInformation("SQLite initialized at {Path}", path);
    }

    public async Task InsertSysmonAsync(SysmonEventRow row, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertAsync(row).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<SysmonEventRow>> QuerySysmonAsync(DateTime? from, DateTime? to, string? typeFilter, string? processFilter, int limit, CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        var q = _db.Table<SysmonEventRow>();
        var list = await q.OrderByDescending(x => x.Timestamp).Take(limit * 4).ToListAsync().ConfigureAwait(false);
        IEnumerable<SysmonEventRow> filtered = list;
        if (!string.IsNullOrEmpty(typeFilter))
            filtered = filtered.Where(x => x.Type.Equals(typeFilter, StringComparison.OrdinalIgnoreCase));
        if (!string.IsNullOrEmpty(processFilter))
            filtered = filtered.Where(x => x.ProcessName.Contains(processFilter, StringComparison.OrdinalIgnoreCase));
        if (from != null)
            filtered = filtered.Where(x => DateTime.TryParse(x.Timestamp, out var t) && t >= from.Value);
        if (to != null)
            filtered = filtered.Where(x => DateTime.TryParse(x.Timestamp, out var t) && t <= to.Value);
        return filtered.Take(limit).ToList();
    }

    public async Task<IReadOnlyList<string>> GetFlaggedProcessNamesAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        var rows = await _db.Table<FlaggedProcessRow>().ToListAsync().ConfigureAwait(false);
        return rows.Select(r => r.Name).ToList();
    }

    public async Task<IReadOnlyList<FlaggedProcessRow>> GetFlaggedProcessesAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        return await _db.Table<FlaggedProcessRow>().ToListAsync().ConfigureAwait(false);
    }

    public async Task AddFlagAsync(string name, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        var existing = await _db.Table<FlaggedProcessRow>().Where(x => x.Name == name).FirstOrDefaultAsync().ConfigureAwait(false);
        var addedAt = string.IsNullOrEmpty(existing?.AddedAt)
            ? DateTime.UtcNow.ToString("O")
            : existing!.AddedAt;
        await _db.InsertOrReplaceAsync(new FlaggedProcessRow { Name = name, AddedAt = addedAt }).ConfigureAwait(false);
    }

    private async Task TryAddFlaggedAddedAtColumnAsync()
    {
        if (_db == null) return;
        try
        {
            await _db.ExecuteAsync("ALTER TABLE FlaggedProcesses ADD COLUMN AddedAt TEXT NOT NULL DEFAULT ''").ConfigureAwait(false);
        }
        catch
        {
        }

        var rows = await _db.Table<FlaggedProcessRow>().ToListAsync().ConfigureAwait(false);
        foreach (var r in rows)
        {
            if (string.IsNullOrEmpty(r.AddedAt))
            {
                r.AddedAt = DateTime.UtcNow.ToString("O");
                await _db.UpdateAsync(r).ConfigureAwait(false);
            }
        }
    }

    public async Task RemoveFlagAsync(string name, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        // Case-insensitive: UI / Sysmon may differ in casing from the stored row.
        await _db.ExecuteAsync("DELETE FROM FlaggedProcesses WHERE lower(Name) = lower(?)", name).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<FirewallBlockRow>> GetFirewallBlocksAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        return await _db.Table<FirewallBlockRow>().ToListAsync().ConfigureAwait(false);
    }

    public async Task AddFirewallBlockAsync(string ip, string direction, string? sourceProcessName, int remotePort = 0, string? expiresAtUtc = null, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new FirewallBlockRow
        {
            Ip = ip,
            Direction = direction,
            CreatedAt = DateTime.UtcNow.ToString("O"),
            SourceProcessName = sourceProcessName ?? "",
            RemotePort = remotePort,
            ExpiresAt = expiresAtUtc ?? ""
        }).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<FirewallProcessBlockRow>> GetFirewallProcessBlocksAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        return await _db.Table<FirewallProcessBlockRow>().ToListAsync().ConfigureAwait(false);
    }

    public async Task AddFirewallProcessBlockAsync(string ruleKey, string processName, string direction, string executablePath, string? expiresAtUtc, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new FirewallProcessBlockRow
        {
            RuleKey = ruleKey,
            ProcessName = processName,
            Direction = direction,
            ExecutablePath = executablePath,
            CreatedAt = DateTime.UtcNow.ToString("O"),
            ExpiresAt = expiresAtUtc ?? ""
        }).ConfigureAwait(false);
    }

    public async Task RemoveFirewallProcessBlockAsync(string ruleKey, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.DeleteAsync<FirewallProcessBlockRow>(ruleKey).ConfigureAwait(false);
    }

    private async Task TryAddFirewallSourceProcessColumnAsync()
    {
        if (_db == null) return;
        try
        {
            await _db.ExecuteAsync("ALTER TABLE FirewallBlocks ADD COLUMN SourceProcessName TEXT NOT NULL DEFAULT ''").ConfigureAwait(false);
        }
        catch
        {
            // Column already present on existing DBs.
        }
    }

    private async Task TryAddFirewallRemotePortExpiresColumnsAsync()
    {
        if (_db == null) return;
        try
        {
            await _db.ExecuteAsync("ALTER TABLE FirewallBlocks ADD COLUMN RemotePort INTEGER NOT NULL DEFAULT 0").ConfigureAwait(false);
        }
        catch { }
        try
        {
            await _db.ExecuteAsync("ALTER TABLE FirewallBlocks ADD COLUMN ExpiresAt TEXT NOT NULL DEFAULT ''").ConfigureAwait(false);
        }
        catch { }
    }

    public async Task RemoveFirewallBlockAsync(string ip, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.DeleteAsync<FirewallBlockRow>(ip).ConfigureAwait(false);
    }

    public async Task<bool> GetIsolationAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return false;
        var row = await _db.Table<IsolationStateRow>().Where(x => x.Id == 1).FirstOrDefaultAsync().ConfigureAwait(false);
        return row?.IsIsolated ?? false;
    }

    public async Task SetIsolationAsync(bool isolated, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new IsolationStateRow { Id = 1, IsIsolated = isolated }).ConfigureAwait(false);
    }

    public async Task AppendAuditAsync(string action, string detail, string? clientIp, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertAsync(new AuditLogRow
        {
            Timestamp = DateTime.UtcNow.ToString("O"),
            Action = action,
            Detail = detail,
            ClientIp = clientIp
        }).ConfigureAwait(false);
    }

    public async Task AckAlertAsync(string alertId, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new AlertAckRow { AlertId = alertId, AckedAt = DateTime.UtcNow.ToString("O") }).ConfigureAwait(false);
    }

    public async Task<bool> IsBadIpAsync(string ip, CancellationToken cancellationToken = default)
    {
        if (_db == null) return false;
        var row = await _db.Table<BadIpRow>().Where(x => x.Ip == ip).FirstOrDefaultAsync().ConfigureAwait(false);
        if (row == null) return false;
        if (!string.IsNullOrEmpty(row.ExpiresAt) &&
            DateTime.TryParse(row.ExpiresAt, out var exp) &&
            exp <= DateTime.UtcNow)
            return false;
        return true;
    }

    /// <summary>Lookup metadata for an IP if it is active in the threat list.</summary>
    public async Task<BadIpRow?> GetBadIpRowAsync(string ip, CancellationToken cancellationToken = default)
    {
        if (_db == null) return null;
        var row = await _db.Table<BadIpRow>().Where(x => x.Ip == ip).FirstOrDefaultAsync().ConfigureAwait(false);
        if (row == null) return null;
        if (!string.IsNullOrEmpty(row.ExpiresAt) &&
            DateTime.TryParse(row.ExpiresAt, out var exp) &&
            exp <= DateTime.UtcNow)
            return null;
        return row;
    }

    public async Task AddBadIpAsync(string ip, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new BadIpRow
        {
            Ip = ip,
            Source = "manual",
            Category = "blocklist",
            AddedAt = DateTime.UtcNow.ToString("O"),
            ExpiresAt = ""
        }).ConfigureAwait(false);
    }

    public async Task UpsertThreatIntelIpAsync(string ip, string source, string category, string? expiresAtIso, CancellationToken cancellationToken = default)
    {
        if (_db == null || string.IsNullOrWhiteSpace(ip)) return;
        await _db.InsertOrReplaceAsync(new BadIpRow
        {
            Ip = ip.Trim(),
            Source = source,
            Category = string.IsNullOrWhiteSpace(category) ? "malicious" : category,
            AddedAt = DateTime.UtcNow.ToString("O"),
            ExpiresAt = expiresAtIso ?? ""
        }).ConfigureAwait(false);
    }

    public async Task<int> DeleteExpiredBadIpsAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return 0;
        var nowIso = DateTime.UtcNow.ToString("O");
        return await _db.ExecuteAsync(
            "DELETE FROM BadIpList WHERE ExpiresAt != '' AND ExpiresAt < ?",
            nowIso).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<BadIpRow>> GetActiveBadIpsAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        var nowIso = DateTime.UtcNow.ToString("O");
        return await _db.QueryAsync<BadIpRow>(
            "SELECT * FROM BadIpList WHERE ExpiresAt = '' OR ExpiresAt >= ?",
            nowIso).ConfigureAwait(false);
    }

    private async Task TryMigrateBadIpColumnsAsync()
    {
        if (_db == null) return;
        foreach (var sql in new[]
                 {
                     "ALTER TABLE BadIpList ADD COLUMN Source TEXT NOT NULL DEFAULT ''",
                     "ALTER TABLE BadIpList ADD COLUMN AddedAt TEXT NOT NULL DEFAULT ''",
                     "ALTER TABLE BadIpList ADD COLUMN ExpiresAt TEXT NOT NULL DEFAULT ''",
                     "ALTER TABLE BadIpList ADD COLUMN Category TEXT NOT NULL DEFAULT ''"
                 })
        {
            try
            {
                await _db.ExecuteAsync(sql).ConfigureAwait(false);
            }
            catch
            {
                // column exists
            }
        }

        var rows = await _db.Table<BadIpRow>().ToListAsync().ConfigureAwait(false);
        foreach (var r in rows)
        {
            if (string.IsNullOrEmpty(r.AddedAt))
            {
                r.AddedAt = DateTime.UtcNow.ToString("O");
                r.Category = string.IsNullOrEmpty(r.Category) ? "legacy" : r.Category;
                await _db.UpdateAsync(r).ConfigureAwait(false);
            }
        }
    }

    public async Task AppendAlertHistoryAsync(string type, string occurredAtIso, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertAsync(new AlertHistoryRow
        {
            OccurredAt = occurredAtIso,
            Type = type
        }).ConfigureAwait(false);
    }

    public async Task PruneAlertHistoryAsync(TimeSpan retain, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        var cutoff = DateTime.UtcNow - retain;
        var cutoffIso = cutoff.ToString("O");
        await _db.ExecuteAsync("DELETE FROM AlertHistory WHERE OccurredAt < ?", cutoffIso).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<TimelineHourDto>> GetTimelineAsync(int hours, CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        hours = Math.Clamp(hours, 1, 168);
        var now = DateTime.UtcNow;
        var floor = new DateTime(now.Year, now.Month, now.Day, now.Hour, 0, 0, DateTimeKind.Utc);
        var bucketStarts = new List<DateTime>();
        for (var i = hours - 1; i >= 0; i--)
            bucketStarts.Add(floor.AddHours(-i));

        static DateTime FloorHour(DateTime t) =>
            new(t.Year, t.Month, t.Day, t.Hour, 0, 0, DateTimeKind.Utc);

        var minTime = bucketStarts[0];
        var dict = bucketStarts.ToDictionary(
            x => x.ToString("O"),
            x => new TimelineHourDto { HourStart = x.ToString("O") });

        var minTimeIso = minTime.ToString("O");
        var evs = await _db.QueryAsync<SysmonEventRow>(
            "SELECT * FROM SysmonEvents WHERE Timestamp >= ?",
            minTimeIso).ConfigureAwait(false);
        foreach (var e in evs)
        {
            if (!DateTime.TryParse(e.Timestamp, null, System.Globalization.DateTimeStyles.RoundtripKind, out var t))
                continue;
            var utc = t.Kind == DateTimeKind.Utc ? t : t.ToUniversalTime();
            if (utc < minTime) continue;
            var fh = FloorHour(utc);
            var k = fh.ToString("O");
            if (!dict.TryGetValue(k, out var dto)) continue;
            switch (e.Type)
            {
                case "ProcessCreate":
                    dto.ProcessCreate++;
                    break;
                case "NetworkConnect":
                    dto.NetworkConnect++;
                    break;
                case "DnsQuery":
                    dto.DnsQuery++;
                    break;
            }
        }

        var ah = await _db.QueryAsync<AlertHistoryRow>(
            "SELECT * FROM AlertHistory WHERE OccurredAt >= ?",
            minTimeIso).ConfigureAwait(false);
        foreach (var a in ah)
        {
            if (!DateTime.TryParse(a.OccurredAt, null, System.Globalization.DateTimeStyles.RoundtripKind, out var t))
                continue;
            var utc = t.Kind == DateTimeKind.Utc ? t : t.ToUniversalTime();
            if (utc < minTime) continue;
            var k = FloorHour(utc).ToString("O");
            if (dict.TryGetValue(k, out var dto))
                dto.Alerts++;
        }

        return dict.Values.OrderBy(x => x.HourStart).ToList();
    }

    public async Task<int> CountEventsSinceAsync(DateTime utcFrom, CancellationToken cancellationToken = default)
    {
        if (_db == null) return 0;
        var iso = utcFrom.ToString("O");
        return await _db.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM SysmonEvents WHERE Timestamp >= ?",
            iso).ConfigureAwait(false);
    }

    public async Task<IReadOnlyDictionary<string, InstalledSoftwareStateRow>> GetInstalledSoftwareStateMapAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return new Dictionary<string, InstalledSoftwareStateRow>(StringComparer.Ordinal);
        var rows = await _db.Table<InstalledSoftwareStateRow>().ToListAsync().ConfigureAwait(false);
        return rows.ToDictionary(r => r.Signature, StringComparer.Ordinal);
    }

    public async Task UpsertInstalledSoftwareStateAsync(InstalledSoftwareStateRow row, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(row).ConfigureAwait(false);
    }

    public async Task ExportSysmonRowsAsync(DateTime from, DateTime to, CancellationToken cancellationToken = default)
    {
        await Task.CompletedTask;
    }

    public async Task AddDeviceTokenAsync(DeviceAuthTokenRow row, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(row).ConfigureAwait(false);
    }

    public async Task<DeviceAuthTokenRow?> FindActiveDeviceTokenByHashAsync(string tokenHash, CancellationToken cancellationToken = default)
    {
        if (_db == null) return null;
        return await _db.Table<DeviceAuthTokenRow>()
            .Where(x => x.TokenHash == tokenHash && !x.Revoked)
            .FirstOrDefaultAsync()
            .ConfigureAwait(false);
    }

    public async Task TouchDeviceTokenAsync(string id, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        var row = await _db.Table<DeviceAuthTokenRow>().Where(x => x.Id == id).FirstOrDefaultAsync().ConfigureAwait(false);
        if (row == null) return;
        row.LastUsedAt = DateTime.UtcNow.ToString("O");
        await _db.UpdateAsync(row).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<DeviceAuthTokenRow>> ListDeviceTokensAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        return await _db.Table<DeviceAuthTokenRow>().OrderByDescending(x => x.LastUsedAt).ToListAsync().ConfigureAwait(false);
    }

    public async Task RevokeDeviceTokenAsync(string id, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        var row = await _db.Table<DeviceAuthTokenRow>().Where(x => x.Id == id).FirstOrDefaultAsync().ConfigureAwait(false);
        if (row == null) return;
        row.Revoked = true;
        await _db.UpdateAsync(row).ConfigureAwait(false);
    }
}
