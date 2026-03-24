namespace EndpointMonitorService.Models;

public sealed class InstalledSoftwareItem
{
    public string Name { get; set; } = "";
    public string Version { get; set; } = "";
    public string InstallDate { get; set; } = "";
    public string Vendor { get; set; } = "";
}
