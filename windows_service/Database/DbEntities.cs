using SQLite;

namespace EndpointMonitorService.Database;

[Table("SysmonEvents")]
public sealed class SysmonEventRow
{
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }

    public int EventId { get; set; }
    public string Timestamp { get; set; } = "";
    public string Type { get; set; } = "";
    public int Pid { get; set; }
    public string ProcessName { get; set; } = "";
    public string? CommandLine { get; set; }
    public int? ParentPid { get; set; }
    public string? RemoteAddress { get; set; }
    public int? RemotePort { get; set; }
    public string? DnsQuery { get; set; }
    public string RawXml { get; set; } = "";
}

[Table("FlaggedProcesses")]
public sealed class FlaggedProcessRow
{
    [PrimaryKey]
    public string Name { get; set; } = "";

    public string AddedAt { get; set; } = "";
}

[Table("FirewallBlocks")]
public sealed class FirewallBlockRow
{
    [PrimaryKey]
    public string Ip { get; set; } = "";
    public string Direction { get; set; } = "";
    public string CreatedAt { get; set; } = "";
    public string SourceProcessName { get; set; } = "";

    /// <summary>0 = not scoped to a remote port.</summary>
    public int RemotePort { get; set; }

    /// <summary>UTC ISO-8601 expiry, or empty for permanent.</summary>
    public string ExpiresAt { get; set; } = "";
}

[Table("FirewallProcessBlocks")]
public sealed class FirewallProcessBlockRow
{
    [PrimaryKey]
    public string RuleKey { get; set; } = "";

    public string ProcessName { get; set; } = "";
    public string Direction { get; set; } = "";
    public string ExecutablePath { get; set; } = "";
    public string CreatedAt { get; set; } = "";
    public string ExpiresAt { get; set; } = "";
}

[Table("AuditLog")]
public sealed class AuditLogRow
{
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }

    public string Timestamp { get; set; } = "";
    public string Action { get; set; } = "";
    public string Detail { get; set; } = "";
    public string? ClientIp { get; set; }
}

[Table("IsolationState")]
public sealed class IsolationStateRow
{
    [PrimaryKey]
    public int Id { get; set; }

    public bool IsIsolated { get; set; }
}

[Table("BadIpList")]
public sealed class BadIpRow
{
    [PrimaryKey]
    public string Ip { get; set; } = "";

    public string Source { get; set; } = "";
    public string AddedAt { get; set; } = "";
    public string ExpiresAt { get; set; } = "";
    public string Category { get; set; } = "";
}

[Table("AlertHistory")]
public sealed class AlertHistoryRow
{
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }

    public string OccurredAt { get; set; } = "";
    public string Type { get; set; } = "";
}

[Table("AlertAck")]
public sealed class AlertAckRow
{
    [PrimaryKey]
    public string AlertId { get; set; } = "";

    public string AckedAt { get; set; } = "";
}
