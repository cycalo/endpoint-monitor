using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace EndpointMonitorService.Services;

/// <summary>Helpers for loopback checks and discovering LAN addresses shown in the tray UI.</summary>
public static class LocalNetworkHelper
{
    public static bool IsLoopback(IPAddress? address)
    {
        if (address == null) return false;
        if (IPAddress.IsLoopback(address)) return true;
        if (address.IsIPv4MappedToIPv6)
            return IPAddress.IsLoopback(address.MapToIPv4());
        return false;
    }

    public static bool IsLoopbackRequest(HttpContext ctx) =>
        IsLoopback(ctx.Connection.RemoteIpAddress);

    /// <summary>Non-loopback IPv4 addresses suitable for phone pairing (skips link-local).</summary>
    public static IReadOnlyList<string> GetLanIPv4Addresses()
    {
        var results = new List<string>();
        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up) continue;
                if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;

                foreach (var ua in ni.GetIPProperties().UnicastAddresses)
                {
                    if (ua.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                    var ip = ua.Address.ToString();
                    if (ip.StartsWith("169.254.", StringComparison.Ordinal)) continue;
                    results.Add(ip);
                }
            }
        }
        catch
        {
            // ignore enumeration failures
        }

        return results.Distinct(StringComparer.Ordinal).OrderBy(s => s, StringComparer.Ordinal).ToList();
    }

    public static string FormatLanAddressesForDisplay(IReadOnlyList<string> ips) =>
        ips.Count == 0 ? "(no LAN IPv4 detected)" : string.Join(Environment.NewLine, ips);
}
