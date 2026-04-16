using System.Management;
using EndpointMonitorService.Models;

namespace EndpointMonitorService.Collectors;

public sealed class ProcessCollector(ILogger<ProcessCollector> logger)
{
    public IReadOnlyList<ProcessInfo> Collect()
    {
        var list = new List<ProcessInfo>();
        var cpuByPid = GetCpuPercentByPid();
        // Win32_PerfFormattedData_PerfProc_Process.PercentProcessorTime can exceed 100% on multi-core
        // systems (max is roughly 100 × logical processor count). Normalize to 0–100% of total CPU.
        var processors = Math.Max(1, Environment.ProcessorCount);

        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT ProcessId, Name, CommandLine, ParentProcessId, WorkingSetSize, CreationDate FROM Win32_Process");
            using var collection = searcher.Get();
            foreach (ManagementObject mo in collection)
            {
                using (mo)
                {
                    try
                    {
                        var pid = Convert.ToInt32(mo["ProcessId"]);
                        var name = mo["Name"]?.ToString() ?? "";
                        var cmd = mo["CommandLine"]?.ToString() ?? "";
                        var parent = mo["ParentProcessId"] != null ? Convert.ToInt32(mo["ParentProcessId"]) : 0;
                        var ws = mo["WorkingSetSize"] != null ? Convert.ToUInt64(mo["WorkingSetSize"]) : 0UL;
                        var memMb = ws / (1024.0 * 1024.0);
                        string start = "";
                        if (mo["CreationDate"] != null)
                        {
                            try
                            {
                                start = ManagementDateTimeConverter.ToDateTime(mo["CreationDate"].ToString()!)
                                    .ToUniversalTime().ToString("O");
                            }
                            catch
                            {
                                start = "";
                            }
                        }

                        cpuByPid.TryGetValue(pid, out var cpu);
                        var cpuNormalized = Math.Clamp(cpu / processors, 0.0, 100.0);
                        list.Add(new ProcessInfo
                        {
                            Pid = pid,
                            Name = name,
                            CommandLine = cmd,
                            ParentPid = parent,
                            CpuPercent = Math.Round(cpuNormalized, 2),
                            MemoryMb = Math.Round(memMb, 2),
                            StartTime = start,
                            Status = "Running"
                        });
                    }
                    catch (Exception ex)
                    {
                        logger.LogDebug(ex, "Skipping process row");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "WMI Win32_Process query failed");
        }

        return list;
    }

    private Dictionary<int, double> GetCpuPercentByPid()
    {
        var result = new Dictionary<int, double>();
        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT IDProcess, Name, PercentProcessorTime FROM Win32_PerfFormattedData_PerfProc_Process WHERE Name <> '_Total' AND Name <> 'Idle'");
            using var collection = searcher.Get();
            foreach (ManagementObject mo in collection)
            {
                using (mo)
                {
                    try
                    {
                        var pid = Convert.ToInt32(mo["IDProcess"]);
                        var pct = mo["PercentProcessorTime"] != null ? Convert.ToDouble(mo["PercentProcessorTime"]) : 0;
                        result[pid] = pct;
                    }
                    catch
                    {
                        // ignore
                    }
                }
            }
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "CPU perf WMI unavailable");
        }

        return result;
    }
}
