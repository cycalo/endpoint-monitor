namespace EndpointMonitorService.Options;

public sealed class ServerOptions
{
    public int Port { get; set; } = 5000;
    public bool UseHttps { get; set; }
    public int HttpsPort { get; set; } = 5001;
}

public sealed class SoftwareMonitoringOptions
{
    /// <summary>Enable scheduled registry-diff checks for newly installed software.</summary>
    public bool Enabled { get; set; } = true;

    /// <summary>Minutes between uninstall-registry snapshot checks.</summary>
    public int InstallCheckIntervalMinutes { get; set; } = 10;

    /// <summary>Safety cap for number of new-install alerts emitted in one run.</summary>
    public int MaxAlertsPerRun { get; set; } = 25;
}
