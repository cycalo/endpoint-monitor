using System.Net;
using Microsoft.Extensions.Hosting;

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

    public static bool IsLoopbackRequest(HttpContext ctx)
    {
        var address = ctx.Connection.RemoteIpAddress;
        if (address == null)
        {
            var env = ctx.RequestServices.GetService<IHostEnvironment>();
            if (env != null && (env.IsDevelopment()
                || string.Equals(env.EnvironmentName, "Testing", StringComparison.OrdinalIgnoreCase)))
                return true;
            return false;
        }

        return IsLoopback(address);
    }

    /// <summary>Non-loopback IPv4 addresses suitable for phone pairing (skips link-local).</summary>
    public static IReadOnlyList<string> GetLanIPv4Addresses() =>
        NetworkEndpoint.Discover().Select(e => e.Ip).ToList();

    public static IReadOnlyList<NetworkEndpoint> GetNetworkEndpoints() =>
        NetworkEndpoint.Discover();

    public static string FormatLanAddressesForDisplay(IReadOnlyList<string> ips) =>
        ips.Count == 0 ? "(no LAN IPv4 detected)" : string.Join(Environment.NewLine, ips);
}
