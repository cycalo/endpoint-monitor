namespace EndpointMonitorService.Options;

public sealed class VirusTotalOptions
{
    public string ApiKey { get; set; } = "";
    public int CacheTtlHours { get; set; } = 24;
}
