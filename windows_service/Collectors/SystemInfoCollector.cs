using System.Diagnostics;
using System.Management;
using EndpointMonitorService.Models;
using Microsoft.Win32;
using static System.Management.ManagementDateTimeConverter;

namespace EndpointMonitorService.Collectors;

public sealed class SystemInfoCollector(ILogger<SystemInfoCollector> logger)
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
            foreach (var d in DriveInfo.GetDrives().Where(d => d.IsReady && d.DriveType == DriveType.Fixed))
            {
                used += (d.TotalSize - d.TotalFreeSpace) / (1024.0 * 1024 * 1024);
                total += d.TotalSize / (1024.0 * 1024 * 1024);
            }

            info.DiskUsedGb = Math.Round(used, 2);
            info.DiskTotalGb = Math.Round(total, 2);
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

        return info;
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

    private static List<string> CollectLoggedOnUsers()
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT Antecedent FROM Win32_LoggedOnUser");
            foreach (ManagementObject mo in searcher.Get())
            {
                try
                {
                    var ant = mo["Antecedent"]?.ToString() ?? "";
                    var idx = ant.IndexOf("Name=\"", StringComparison.Ordinal);
                    if (idx >= 0)
                    {
                        var end = ant.IndexOf('"', idx + 6);
                        if (end > idx)
                            set.Add(ant[(idx + 6)..end]);
                    }
                }
                catch
                {
                    // ignore
                }
            }
        }
        catch
        {
            // ignore
        }

        return set.ToList();
    }
}
