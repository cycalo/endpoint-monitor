namespace EndpointMonitorService.Models;

public sealed class TimelineHourDto
{
    public string HourStart { get; set; } = "";
    public int ProcessCreate { get; set; }
    public int NetworkConnect { get; set; }
    public int DnsQuery { get; set; }
    public int Alerts { get; set; }
}
