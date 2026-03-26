namespace EndpointMonitorService.Models;

public sealed class InstalledSoftwareItem
{
    public string Name { get; set; } = "";
    public string Version { get; set; } = "";
    public string InstallDate { get; set; } = "";
    public string Vendor { get; set; } = "";
    /// <summary>InstallLocation from uninstall registry, when present.</summary>
    public string InstallLocation { get; set; } = "";
    /// <summary>Registry subkey name under Uninstall (identifies this entry for uninstall).</summary>
    public string UninstallRegistrySubKey { get; set; } = "";
    /// <summary>EstimatedSize from registry (KB), 0 if unknown.</summary>
    public int InstallSizeKb { get; set; }
    /// <summary>True when uninstall is allowed (registry has an uninstall command and NoRemove is not set).</summary>
    public bool CanUninstall { get; set; }
}
