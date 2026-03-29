namespace EndpointMonitorService.Options;

public sealed class ThreatIntelOptions
{
    public bool Enabled { get; set; } = true;
    public int UpdateIntervalHours { get; set; } = 24;
    public int FeedEntryTtlDays { get; set; } = 7;
    public Dictionary<string, string> Feeds { get; set; } = new();
}
