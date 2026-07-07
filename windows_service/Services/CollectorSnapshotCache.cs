using EndpointMonitorService.Collectors;
using EndpointMonitorService.Models;
using EndpointMonitorService.Options;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Services;

/// <summary>
/// Deduplicates expensive process/network WMI collection across broadcast loops and on-demand commands.
/// </summary>
public sealed class CollectorSnapshotCache(
    ProcessCollector processCollector,
    NetworkCollector networkCollector,
    IOptionsMonitor<MonitoringOptions> options)
{
    private readonly object _lock = new();
    private IReadOnlyList<ProcessInfo> _processes = [];
    private IReadOnlyList<NetworkConnection> _network = [];
    private DateTime _collectedAtUtc = DateTime.MinValue;

    public readonly record struct Snapshot(
        IReadOnlyList<ProcessInfo> Processes,
        IReadOnlyList<NetworkConnection> Network);

    public Snapshot GetSnapshot(bool forceRefresh = false)
    {
        var ttl = TimeSpan.FromSeconds(Math.Clamp(options.CurrentValue.SnapshotCacheSeconds, 2, 120));
        lock (_lock)
        {
            var fresh = _collectedAtUtc != DateTime.MinValue && DateTime.UtcNow - _collectedAtUtc < ttl;
            if (!forceRefresh && fresh)
                return new Snapshot(_processes, _network);

            _processes = processCollector.Collect();
            _network = networkCollector.Collect();
            _collectedAtUtc = DateTime.UtcNow;
            return new Snapshot(_processes, _network);
        }
    }

    public void Invalidate() => _collectedAtUtc = DateTime.MinValue;
}
