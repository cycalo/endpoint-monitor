using System.Text;
using System.Text.Json;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Tests;

public sealed class PairingQrPayloadTests
{
    [Fact]
    public void BuildUri_includes_lan_and_tailscale_hosts_excludes_other()
    {
        var endpoints = new[]
        {
            new NetworkEndpoint("192.168.1.50", "Wi-Fi", NetworkEndpointKind.Lan),
            new NetworkEndpoint("100.64.0.5", "Tailscale", NetworkEndpointKind.Tailscale),
            new NetworkEndpoint("192.168.177.1", "vEthernet", NetworkEndpointKind.Other),
        };
        var expires = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        var uri = PairingQrPayload.BuildUri("123456", expires, endpoints, 5000);

        Assert.StartsWith("endpointmonitor://pair?data=", uri, StringComparison.Ordinal);
        var json = DecodeDataQuery(uri);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        Assert.Equal(1, root.GetProperty("v").GetInt32());
        Assert.Equal("123456", root.GetProperty("code").GetString());
        Assert.Equal("2026-01-01T00:00:00Z", root.GetProperty("expiresAt").GetString());

        var hosts = root.GetProperty("hosts").EnumerateArray().Select(e => e.GetString()).ToList();
        Assert.Equal(["http://192.168.1.50:5000", "http://100.64.0.5:5000"], hosts);
    }

    [Fact]
    public void BuildUri_uses_default_port_when_httpPort_invalid()
    {
        var endpoints = new[]
        {
            new NetworkEndpoint("10.0.0.2", "Ethernet", NetworkEndpointKind.Lan),
        };
        var expires = DateTime.UtcNow.AddMinutes(5);

        var uri = PairingQrPayload.BuildUri("654321", expires, endpoints, 0);
        var json = DecodeDataQuery(uri);
        using var doc = JsonDocument.Parse(json);
        var hosts = doc.RootElement.GetProperty("hosts").EnumerateArray()
            .Select(e => e.GetString()).ToList();
        Assert.Equal(["http://10.0.0.2:5000"], hosts);
    }

    [Fact]
    public void BuildUri_hosts_empty_when_only_other_adapters()
    {
        var endpoints = new[]
        {
            new NetworkEndpoint("192.168.177.1", "vEthernet", NetworkEndpointKind.Other),
        };
        var uri = PairingQrPayload.BuildUri("123456", DateTime.UtcNow.AddMinutes(5), endpoints, 5000);
        var json = DecodeDataQuery(uri);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal(0, doc.RootElement.GetProperty("hosts").GetArrayLength());
    }

    [Fact]
    public void BuildUri_data_is_base64url_without_padding()
    {
        var endpoints = new[]
        {
            new NetworkEndpoint("192.168.1.1", "Wi-Fi", NetworkEndpointKind.Lan),
        };
        var uri = PairingQrPayload.BuildUri("111111", DateTime.UtcNow.AddMinutes(5), endpoints, 5000);
        var data = uri["endpointmonitor://pair?data=".Length..];
        Assert.DoesNotContain('=', data);
        Assert.DoesNotContain('+', data);
        Assert.DoesNotContain('/', data);
    }

    private static string DecodeDataQuery(string uri)
    {
        const string prefix = "endpointmonitor://pair?data=";
        Assert.StartsWith(prefix, uri, StringComparison.Ordinal);
        var data = uri[prefix.Length..];
        var padded = data.Replace('-', '+').Replace('_', '/');
        switch (padded.Length % 4)
        {
            case 2: padded += "=="; break;
            case 3: padded += "="; break;
        }
        return Encoding.UTF8.GetString(Convert.FromBase64String(padded));
    }
}
