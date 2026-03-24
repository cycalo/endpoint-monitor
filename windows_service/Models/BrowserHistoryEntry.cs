namespace EndpointMonitorService.Models;

public sealed class BrowserHistoryEntry
{
    public string Browser { get; set; } = "";
    public string Url { get; set; } = "";
    public string Title { get; set; } = "";
    public string VisitTime { get; set; } = "";
    public int VisitCount { get; set; }
}
