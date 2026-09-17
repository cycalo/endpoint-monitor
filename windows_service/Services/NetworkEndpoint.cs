using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace EndpointMonitorService.Services;

public enum NetworkEndpointKind
{
    Lan,
    Tailscale,
    Other,
}

public sealed record NetworkEndpoint(string Ip, string Adapter, NetworkEndpointKind Kind)
{
    public string KindKey => Kind switch
    {
        NetworkEndpointKind.Lan => "lan",
        NetworkEndpointKind.Tailscale => "tailscale",
        _ => "other",
    };

    /// <summary>Tailscale uses CGNAT 100.64.0.0/10.</summary>
    public static bool IsTailscaleAddress(string ip)
    {
        if (!IPAddress.TryParse(ip, out var address) || address.AddressFamily != AddressFamily.InterNetwork)
            return false;

        var bytes = address.GetAddressBytes();
        if (bytes[0] != 100)
            return false;
        return bytes[1] >= 64 && bytes[1] <= 127;
    }

    public static bool IsPrivateLanAddress(string ip)
    {
        if (!IPAddress.TryParse(ip, out var address) || address.AddressFamily != AddressFamily.InterNetwork)
            return false;

        var bytes = address.GetAddressBytes();
        if (bytes[0] == 10)
            return true;
        if (bytes[0] == 192 && bytes[1] == 168)
            return true;
        if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31)
            return true;
        return false;
    }

    public static bool LooksLikeWifiAdapter(string adapter)
    {
        var n = adapter.ToLowerInvariant();
        return n.Contains("wi-fi", StringComparison.Ordinal)
            || n.Contains("wifi", StringComparison.Ordinal)
            || n.Contains("wireless", StringComparison.Ordinal)
            || n.Contains("wlan", StringComparison.Ordinal);
    }

    public static bool LooksLikeVirtualAdapter(string adapter)
    {
        var n = adapter.ToLowerInvariant();
        if (n.Contains("tailscale", StringComparison.Ordinal))
            return false;
        return n.Contains("vethernet", StringComparison.Ordinal)
            || n.Contains("hyper-v", StringComparison.Ordinal)
            || n.Contains("vmware", StringComparison.Ordinal)
            || n.Contains("virtualbox", StringComparison.Ordinal)
            || n.Contains("virtual", StringComparison.Ordinal)
            || n.Contains("bluetooth", StringComparison.Ordinal)
            || n.Contains("docker", StringComparison.Ordinal)
            || n.Contains("wsl", StringComparison.Ordinal)
            || n.Contains("loopback", StringComparison.Ordinal);
    }

    public static bool LooksLikeTailscaleAdapter(string adapter) =>
        adapter.Contains("tailscale", StringComparison.OrdinalIgnoreCase);

    public static NetworkEndpointKind Classify(string ip, string adapter)
    {
        if (IsTailscaleAddress(ip) || LooksLikeTailscaleAdapter(adapter))
            return NetworkEndpointKind.Tailscale;
        if (LooksLikeVirtualAdapter(adapter))
            return NetworkEndpointKind.Other;
        if (IsPrivateLanAddress(ip))
            return NetworkEndpointKind.Lan;
        return NetworkEndpointKind.Other;
    }

    public static NetworkEndpoint? PreferredLan(IReadOnlyList<NetworkEndpoint> endpoints)
    {
        var lan = endpoints.Where(e => e.Kind == NetworkEndpointKind.Lan).ToList();
        if (lan.Count == 0)
            return null;
        return lan.FirstOrDefault(e => LooksLikeWifiAdapter(e.Adapter)) ?? lan[0];
    }

    public static NetworkEndpoint? PreferredTailscale(IReadOnlyList<NetworkEndpoint> endpoints) =>
        endpoints.FirstOrDefault(e => e.Kind == NetworkEndpointKind.Tailscale);

    public static string FormatRemaining(TimeSpan remaining)
    {
        if (remaining <= TimeSpan.Zero)
            return "Expired";
        var seconds = (int)Math.Ceiling(remaining.TotalSeconds);
        return $"{seconds / 60}:{seconds % 60:D2}";
    }

    public static IReadOnlyList<NetworkEndpoint> Discover()
    {
        var results = new List<NetworkEndpoint>();
        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up) continue;
                if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;

                var adapter = string.IsNullOrWhiteSpace(ni.Name) ? ni.Description : ni.Name;
                foreach (var ua in ni.GetIPProperties().UnicastAddresses)
                {
                    if (ua.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                    var ip = ua.Address.ToString();
                    if (ip.StartsWith("169.254.", StringComparison.Ordinal)) continue;
                    results.Add(new NetworkEndpoint(ip, adapter, Classify(ip, adapter)));
                }
            }
        }
        catch
        {
            // ignore enumeration failures
        }

        return results
            .DistinctBy(e => e.Ip, StringComparer.Ordinal)
            .OrderBy(e => e.Kind)
            .ThenBy(e => LooksLikeWifiAdapter(e.Adapter) ? 0 : 1)
            .ThenBy(e => e.Adapter, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}
