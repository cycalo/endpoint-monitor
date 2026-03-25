namespace EndpointMonitorService.Models;

public sealed class NetworkConnection
{
    public int Pid { get; set; }
    public string ProcessName { get; set; } = "";
    public string LocalAddress { get; set; } = "";
    public int LocalPort { get; set; }
    public string RemoteAddress { get; set; } = "";
    public int RemotePort { get; set; }
    public string Protocol { get; set; } = "";
    public string State { get; set; } = "";
    public long DurationSeconds { get; set; }

    public string CountryCode { get; set; } = "";
    public string CountryName { get; set; } = "";
    public string City { get; set; } = "";
    public string Org { get; set; } = "";
}
