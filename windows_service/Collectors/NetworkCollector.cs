using System.Management;
using EndpointMonitorService.Models;

namespace EndpointMonitorService.Collectors;

public sealed class NetworkCollector(ILogger<NetworkCollector> logger)
{
    public IReadOnlyList<NetworkConnection> Collect()
    {
        var pidToName = GetProcessNames();
        var list = new List<NetworkConnection>();

        CollectTcp(list, pidToName);
        CollectUdp(list, pidToName);

        return list;
    }

    private static Dictionary<int, string> GetProcessNames()
    {
        var map = new Dictionary<int, string>();
        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT ProcessId, Name FROM Win32_Process");
            foreach (ManagementObject mo in searcher.Get())
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
            foreach (ManagementObject mo in searcher.Get())
            {
                try
                {
                    var pid = mo["OwningProcess"] != null ? Convert.ToInt32(mo["OwningProcess"]) : 0;
                    pidToName.TryGetValue(pid, out var pname);
                    list.Add(new NetworkConnection
                    {
                        Pid = pid,
                        ProcessName = pname ?? "",
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
            foreach (ManagementObject mo in searcher.Get())
            {
                try
                {
                    var pid = mo["OwningProcess"] != null ? Convert.ToInt32(mo["OwningProcess"]) : 0;
                    pidToName.TryGetValue(pid, out var pname);
                    list.Add(new NetworkConnection
                    {
                        Pid = pid,
                        ProcessName = pname ?? "",
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
        catch (Exception ex)
        {
            logger.LogWarning(ex, "MSFT_NetUDPEndpoint query failed");
        }
    }
}
