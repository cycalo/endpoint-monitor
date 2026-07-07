namespace EndpointMonitorService.Options;

/// <summary>Telemetry polling intervals and idle behaviour for WMI collectors.</summary>
public sealed class MonitoringOptions
{
    /// <summary>Seconds between process/network broadcasts when at least one WebSocket client is connected.</summary>
    public int ActiveBroadcastIntervalSeconds { get; set; } = 5;

    /// <summary>Seconds between loop iterations when no WebSocket clients are connected (skips WMI collection).</summary>
    public int IdleIntervalSeconds { get; set; } = 30;

    /// <summary>Seconds between system_info broadcasts when clients are connected.</summary>
    public int SystemInfoIntervalSeconds { get; set; } = 10;

    /// <summary>Reuse process/network WMI snapshots younger than this many seconds (avoids duplicate queries).</summary>
    public int SnapshotCacheSeconds { get; set; } = 5;

    /// <summary>Reuse full system_info WMI snapshot younger than this many seconds.</summary>
    public int SystemInfoCacheSeconds { get; set; } = 10;
}
