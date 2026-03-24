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
        await _db.CreateTableAsync<FirewallBlockRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<AuditLogRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<IsolationStateRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<BadIpRow>().ConfigureAwait(false);
        await _db.CreateTableAsync<AlertAckRow>().ConfigureAwait(false);

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

    public async Task AddFlagAsync(string name, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new FlaggedProcessRow { Name = name }).ConfigureAwait(false);
    }

    public async Task RemoveFlagAsync(string name, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.ExecuteAsync("DELETE FROM FlaggedProcesses WHERE Name = ?", name).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<FirewallBlockRow>> GetFirewallBlocksAsync(CancellationToken cancellationToken = default)
    {
        if (_db == null) return [];
        return await _db.Table<FirewallBlockRow>().ToListAsync().ConfigureAwait(false);
    }

    public async Task AddFirewallBlockAsync(string ip, string direction, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new FirewallBlockRow
        {
            Ip = ip,
            Direction = direction,
            CreatedAt = DateTime.UtcNow.ToString("O")
        }).ConfigureAwait(false);
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
        return await _db.Table<BadIpRow>().Where(x => x.Ip == ip).CountAsync() > 0;
    }

    public async Task AddBadIpAsync(string ip, CancellationToken cancellationToken = default)
    {
        if (_db == null) return;
        await _db.InsertOrReplaceAsync(new BadIpRow { Ip = ip }).ConfigureAwait(false);
    }

    public async Task<int> CountEventsSinceAsync(DateTime utcFrom, CancellationToken cancellationToken = default)
    {
        if (_db == null) return 0;
        var rows = await _db.Table<SysmonEventRow>().ToListAsync().ConfigureAwait(false);
        return rows.Count(r => DateTime.TryParse(r.Timestamp, out var t) && t >= utcFrom);
    }

    public async Task ExportSysmonRowsAsync(DateTime from, DateTime to, CancellationToken cancellationToken = default)
    {
        await Task.CompletedTask;
    }
}
