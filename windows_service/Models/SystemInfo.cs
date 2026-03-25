namespace EndpointMonitorService.Models;

public sealed class SystemInfo
{
    /// <summary>Computer name (same as Windows “Device name” / DNS host name).</summary>
    public string SystemName { get; set; } = "";

    public double CpuPercent { get; set; }
    public double RamUsedGb { get; set; }
    public double RamTotalGb { get; set; }
    public double DiskUsedGb { get; set; }
    public double DiskTotalGb { get; set; }
    public string Uptime { get; set; } = "";

    /// <summary>Friendly OS title from WMI when available (e.g. Microsoft Windows 11 Pro).</summary>
    public string OsCaption { get; set; } = "";

    public string OsVersion { get; set; } = "";
    public string OsArchitecture { get; set; } = "";
    public string PatchLevel { get; set; } = "";

    /// <summary>Active Directory DNS domain, or workgroup name on workgroup PCs.</summary>
    public string Domain { get; set; } = "";

    /// <summary>First IPv4-enabled adapter description (e.g. Intel Wi-Fi).</summary>
    public string PrimaryNetworkDescription { get; set; } = "";

    /// <summary>IPv4 on that adapter (not loopback).</summary>
    public string PrimaryNetworkIpv4 { get; set; } = "";

    /// <summary>Endpoint Monitor Windows service build (informational or assembly version).</summary>
    public string AgentVersion { get; set; } = "";

    /// <summary>Sysmon driver/service: Not installed | Stopped | Running.</summary>
    public string SysmonStatus { get; set; } = "";

    /// <summary>Last boot time in local time, yyyy-MM-dd HH:mm:ss.</summary>
    public string LastBootTime { get; set; } = "";
    public List<string> LoggedInUsers { get; set; } = [];
    public int ProcessCount { get; set; }
    public int NetworkConnectionCount { get; set; }
    public int EventsTodayCount { get; set; }
}
