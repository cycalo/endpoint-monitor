namespace EndpointMonitorService.Models;

public sealed class SysmonEvent
{
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
