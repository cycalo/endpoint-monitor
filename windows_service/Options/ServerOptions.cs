namespace EndpointMonitorService.Options;

public sealed class ServerOptions
{
    public int Port { get; set; } = 5000;
    public bool UseHttps { get; set; }
    public int HttpsPort { get; set; } = 5001;
}
