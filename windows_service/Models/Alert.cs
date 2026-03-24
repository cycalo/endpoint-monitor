namespace EndpointMonitorService.Models;

public sealed class Alert
{
    public string Id { get; set; } = "";
    public string Timestamp { get; set; } = "";
    public string Severity { get; set; } = "";
    public string Type { get; set; } = "";
    public string Message { get; set; } = "";
    public int? RelatedPid { get; set; }
}
