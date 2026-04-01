using System.Diagnostics;
using System.Management;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using EndpointMonitorService.Models;
using Microsoft.Win32;
using static System.Management.ManagementDateTimeConverter;

namespace EndpointMonitorService.Collectors;

public sealed class SystemInfoCollector(
    ILogger<SystemInfoCollector> logger,
    NetworkThroughputCollector networkThroughput)
{
    private readonly PerformanceCounter? _cpuCounter = CreateCpuCounter();

    private static PerformanceCounter? CreateCpuCounter()
    {
        try
        {
            var c = new PerformanceCounter("Processor", "% Processor Time", "_Total", true);
            c.NextValue();
            return c;
        }
        catch (Exception ex)
        {
            Debug.WriteLine(ex);
            return null;
        }
    }

    public SystemInfo Collect()
    {
        var info = new SystemInfo();
        try
        {
            info.SystemName = Environment.MachineName;
        }
        catch
        {
            info.SystemName = "";
        }

        try
        {
            if (_cpuCounter != null)
                info.CpuPercent = Math.Round(_cpuCounter.NextValue(), 2);
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "CPU counter failed");
        }

        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT Caption, OSArchitecture, LastBootUpTime, FreePhysicalMemory, TotalVisibleMemorySize FROM Win32_OperatingSystem");
            foreach (ManagementObject mo in searcher.Get())
            {
                info.OsCaption = mo["Caption"]?.ToString() ?? "";
                info.OsArchitecture = mo["OSArchitecture"]?.ToString() ?? "";
                var lbs = mo["LastBootUpTime"]?.ToString();
                if (!string.IsNullOrEmpty(lbs))
                {
                    try
                    {
                        var boot = ToDateTime(lbs);
                        info.LastBootTime = boot.ToString("yyyy-MM-dd HH:mm:ss");
                    }
                    catch
                    {
                        // ignore parse errors
                    }
                }

                var freeKb = Convert.ToDouble(mo["FreePhysicalMemory"]);
                var totalKb = Convert.ToDouble(mo["TotalVisibleMemorySize"]);
                info.RamTotalGb = Math.Round(totalKb / (1024 * 1024), 2);
                info.RamUsedGb = Math.Round((totalKb - freeKb) / (1024 * 1024), 2);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Win32_OperatingSystem WMI failed");
        }

        try
        {
            using var csSearcher = new ManagementObjectSearcher("SELECT Domain FROM Win32_ComputerSystem");
            foreach (ManagementObject mo in csSearcher.Get())
            {
                info.Domain = mo["Domain"]?.ToString() ?? "";
                break;
            }
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Win32_ComputerSystem Domain failed");
        }

        try
        {
            double used = 0, total = 0;
            var disks = new List<DiskVolumeInfo>();
            foreach (var d in DriveInfo.GetDrives()
                         .Where(x => x.IsReady && x.DriveType == DriveType.Fixed)
                         .OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase))
            {
                var volUsed = (d.TotalSize - d.TotalFreeSpace) / (1024.0 * 1024 * 1024);
                var volTotal = d.TotalSize / (1024.0 * 1024 * 1024);
                used += volUsed;
                total += volTotal;
                var label = "";
                try
                {
                    label = d.VolumeLabel?.Trim() ?? "";
                }
                catch
                {
                    // Some volumes throw on label access
                }

                disks.Add(new DiskVolumeInfo
                {
                    Name = d.Name,
                    Label = label,
                    UsedGb = Math.Round(volUsed, 2),
                    TotalGb = Math.Round(volTotal, 2)
                });
            }

            info.DiskUsedGb = Math.Round(used, 2);
            info.DiskTotalGb = Math.Round(total, 2);
            info.Disks = disks;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Disk info failed");
        }

        try
        {
            var uptime = TimeSpan.FromMilliseconds(Environment.TickCount64);
            info.Uptime = $"{(int)uptime.TotalDays}d {uptime.Hours}h {uptime.Minutes}m";
        }
        catch
        {
            info.Uptime = "";
        }

        info.OsVersion = Environment.OSVersion.VersionString;
        info.PatchLevel = ReadPatchLevel();
        info.LoggedInUsers = CollectLoggedOnUsers();
        info.AgentVersion = CollectAgentVersion();
        info.SysmonStatus = CollectSysmonStatus();
        var (netDesc, netIp) = CollectPrimaryNetwork();
        info.PrimaryNetworkDescription = netDesc;
        info.PrimaryNetworkIpv4 = netIp;

        try
        {
            networkThroughput.Sample(out var sent, out var recv);
            info.NetworkBytesSentPerSec = Math.Round(sent, 2);
            info.NetworkBytesReceivedPerSec = Math.Round(recv, 2);
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Network throughput sample failed");
        }

        return info;
    }

    private static string CollectAgentVersion()
    {
        try
        {
            var a = typeof(SystemInfoCollector).Assembly;
            var info = a.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
            if (!string.IsNullOrWhiteSpace(info))
            {
                var plus = info.IndexOf('+', StringComparison.Ordinal);
                return plus > 0 ? info[..plus] : info;
            }

            var v = a.GetName().Version;
            return v?.ToString() ?? "";
        }
        catch
        {
            return "";
        }
    }

    private static string CollectSysmonStatus()
    {
        try
        {
            using var s = new ManagementObjectSearcher(
                "SELECT State FROM Win32_Service WHERE Name='Sysmon64' OR Name='Sysmon'");
            foreach (ManagementObject mo in s.Get())
            {
                var state = mo["State"]?.ToString() ?? "";
                if (string.Equals(state, "Running", StringComparison.OrdinalIgnoreCase))
                    return "Running";
                if (string.Equals(state, "Stopped", StringComparison.OrdinalIgnoreCase))
                    return "Stopped";
            }
        }
        catch
        {
            // ignore
        }

        return "Not installed";
    }

    private static (string Description, string Ipv4) CollectPrimaryNetwork()
    {
        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT Description, IPAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled=True");
            foreach (ManagementObject mo in searcher.Get())
            {
                var desc = mo["Description"]?.ToString()?.Trim() ?? "";
                if (mo["IPAddress"] is not string[] ips) continue;
                foreach (var ip in ips)
                {
                    if (string.IsNullOrWhiteSpace(ip)) continue;
                    if (!IPAddress.TryParse(ip, out var addr)) continue;
                    if (addr.AddressFamily != AddressFamily.InterNetwork) continue;
                    if (IPAddress.IsLoopback(addr)) continue;
                    if (ip.StartsWith("169.254.", StringComparison.Ordinal)) continue;
                    return (desc, ip);
                }
            }

            foreach (ManagementObject mo in searcher.Get())
            {
                var desc = mo["Description"]?.ToString()?.Trim() ?? "";
                if (mo["IPAddress"] is not string[] ips2) continue;
                foreach (var ip in ips2)
                {
                    if (string.IsNullOrWhiteSpace(ip)) continue;
                    if (!IPAddress.TryParse(ip, out var addr)) continue;
                    if (addr.AddressFamily != AddressFamily.InterNetwork) continue;
                    if (IPAddress.IsLoopback(addr)) continue;
                    return (desc, ip);
                }
            }
        }
        catch
        {
            // ignore
        }

        return ("", "");
    }

    private static string ReadPatchLevel()
    {
        try
        {
            using var k = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            var ub = k?.GetValue("UBR")?.ToString();
            var build = k?.GetValue("CurrentBuild")?.ToString();
            if (!string.IsNullOrEmpty(build))
                return string.IsNullOrEmpty(ub) ? build : $"{build}.{ub}";
        }
        catch
        {
            // ignore
        }

        return "";
    }

    /// <summary>
    /// Uses Win32_ComputerSystem.UserName for the logged-on user; falls back to Environment.UserName when null/empty.
    /// </summary>
    private static List<string> CollectLoggedOnUsers()
    {
        string? user = null;
        try
        {
            using var searcher = new ManagementObjectSearcher("SELECT UserName FROM Win32_ComputerSystem");
            foreach (ManagementObject mo in searcher.Get())
            {
                user = mo["UserName"]?.ToString()?.Trim();
                break;
            }
        }
        catch
        {
            // ignore
        }

        if (string.IsNullOrWhiteSpace(user))
            user = Environment.UserName;

        user = user?.Trim();
        if (string.IsNullOrEmpty(user))
            return [];

        return [user];
    }
}
