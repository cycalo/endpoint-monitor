using System.Collections.Concurrent;
using System.Management;
using EndpointMonitorService.Models;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Collectors;

public sealed class NetworkCollector(ILogger<NetworkCollector> logger, GeoIpLookupService geo)
{
    private readonly ConcurrentDictionary<string, DateTime> _firstSeenUtc = new(StringComparer.Ordinal);

    public IReadOnlyList<NetworkConnection> Collect()
    {
        var pidToName = GetProcessNames();
        var list = new List<NetworkConnection>();
        var now = DateTime.UtcNow;
        var seenKeys = new HashSet<string>(StringComparer.Ordinal);

        CollectTcp(list, pidToName);
        CollectUdp(list, pidToName);

        foreach (var c in list)
        {
            var key = BuildConnectionKey(c);
            seenKeys.Add(key);
            var firstSeen = _firstSeenUtc.GetOrAdd(key, now);
            var elapsed = now - firstSeen;
            c.DurationSeconds = Math.Max(0, (long)elapsed.TotalSeconds);

            if (string.IsNullOrWhiteSpace(c.RemoteAddress)) continue;
            var g = geo.Lookup(c.RemoteAddress);
            c.CountryCode = g.CountryCode;
            c.CountryName = g.CountryName;
            c.City = g.City;
            c.Org = g.Org;
        }

        foreach (var key in _firstSeenUtc.Keys)
        {
            if (!seenKeys.Contains(key))
                _firstSeenUtc.TryRemove(key, out _);
        }

        return list;
    }

    private static string BuildConnectionKey(NetworkConnection c)
        => $"{c.Pid}|{c.LocalAddress}|{c.LocalPort}|{c.RemoteAddress}|{c.RemotePort}|{c.Protocol}";

    /// <summary>
    /// <see cref="MSFT_NetTCPConnection.OwningProcess"/> can be 0; Win32_Process then resolves PID 0
    /// to "System Idle Process", which is misleading — idle does not own sockets. Show a neutral label.
    /// </summary>
    private static string FormatOwningProcess(int pid, string? nameFromWmi)
    {
        if (pid <= 0)
            return "Unattributed";
        if (string.IsNullOrWhiteSpace(nameFromWmi))
            return $"PID {pid}";
        return nameFromWmi;
    }

    private static Dictionary<int, string> GetProcessNames()
    {
        var map = new Dictionary<int, string>();
        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT ProcessId, Name FROM Win32_Process");
            using var collection = searcher.Get();
            foreach (ManagementObject mo in collection)
            {
                using (mo)
                {
                    try
                    {
                        var pid = Convert.ToInt32(mo["ProcessId"]);
                        map[pid] = mo["Name"]?.ToString() ?? "";
                    }
                    catch
                    {
                        // ignore
                    }
                }
            }
        }
        catch
        {
            // ignore
        }

        return map;
    }

    private void CollectTcp(List<NetworkConnection> list, IReadOnlyDictionary<int, string> pidToName)
    {
        try
        {
            var scope = new ManagementScope(@"root\StandardCimv2");
            scope.Connect();
            using var searcher = new ManagementObjectSearcher(scope, new ObjectQuery(
                "SELECT LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess FROM MSFT_NetTCPConnection"));
            using var collection = searcher.Get();
            foreach (ManagementObject mo in collection)
            {
                using (mo)
                {
                    try
                    {
                        var pid = mo["OwningProcess"] != null ? Convert.ToInt32(mo["OwningProcess"]) : 0;
                        pidToName.TryGetValue(pid, out var pname);
                        list.Add(new NetworkConnection
                        {
                            Pid = pid,
                            ProcessName = FormatOwningProcess(pid, pname),
                            LocalAddress = mo["LocalAddress"]?.ToString() ?? "",
                            LocalPort = mo["LocalPort"] != null ? Convert.ToInt32(mo["LocalPort"]) : 0,
                            RemoteAddress = mo["RemoteAddress"]?.ToString() ?? "",
                            RemotePort = mo["RemotePort"] != null ? Convert.ToInt32(mo["RemotePort"]) : 0,
                            Protocol = "TCP",
                            State = mo["State"]?.ToString() ?? ""
                        });
                    }
                    catch (Exception ex)
                    {
                        logger.LogDebug(ex, "TCP row skip");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "MSFT_NetTCPConnection query failed");
        }
    }

    private void CollectUdp(List<NetworkConnection> list, IReadOnlyDictionary<int, string> pidToName)
    {
        try
        {
            var scope = new ManagementScope(@"root\StandardCimv2");
            scope.Connect();
            using var searcher = new ManagementObjectSearcher(scope, new ObjectQuery(
                "SELECT LocalAddress, LocalPort, OwningProcess FROM MSFT_NetUDPEndpoint"));
            using var collection = searcher.Get();
            foreach (ManagementObject mo in collection)
            {
                using (mo)
                {
                    try
                    {
                        var pid = mo["OwningProcess"] != null ? Convert.ToInt32(mo["OwningProcess"]) : 0;
                        pidToName.TryGetValue(pid, out var pname);
                        list.Add(new NetworkConnection
                        {
                            Pid = pid,
                            ProcessName = FormatOwningProcess(pid, pname),
                            LocalAddress = mo["LocalAddress"]?.ToString() ?? "",
                            LocalPort = mo["LocalPort"] != null ? Convert.ToInt32(mo["LocalPort"]) : 0,
                            RemoteAddress = "",
                            RemotePort = 0,
                            Protocol = "UDP",
                            State = ""
                        });
                    }
                    catch (Exception ex)
                    {
                        logger.LogDebug(ex, "UDP row skip");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "MSFT_NetUDPEndpoint query failed");
        }
    }
}
