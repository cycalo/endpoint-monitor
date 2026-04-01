namespace EndpointMonitorService.Models;

/// <summary>One fixed local volume (e.g. C:\) with used/total space in GiB.</summary>
public sealed class DiskVolumeInfo
{
    /// <summary>Root path, typically "C:\".</summary>
    public string Name { get; set; } = "";

    /// <summary>Volume label when available (may be empty).</summary>
    public string Label { get; set; } = "";

    public double UsedGb { get; set; }
    public double TotalGb { get; set; }
}
