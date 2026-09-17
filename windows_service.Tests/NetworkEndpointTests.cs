using EndpointMonitorService.Services;

namespace EndpointMonitorService.Tests;

public sealed class NetworkEndpointTests
{
    [Theory]
    [InlineData("100.87.181.68", true)]
    [InlineData("100.64.0.1", true)]
    [InlineData("100.127.255.255", true)]
    [InlineData("100.63.255.255", false)]
    [InlineData("100.128.0.1", false)]
    [InlineData("192.168.1.71", false)]
    [InlineData("10.0.0.2", false)]
    public void IsTailscaleAddress_matches_cgnat_range(string ip, bool expected)
    {
        Assert.Equal(expected, NetworkEndpoint.IsTailscaleAddress(ip));
    }

    [Fact]
    public void Classify_prefers_tailscale_over_adapter_name()
    {
        var kind = NetworkEndpoint.Classify("100.87.181.68", "Tailscale");
        Assert.Equal(NetworkEndpointKind.Tailscale, kind);
    }

    [Fact]
    public void Classify_marks_private_wifi_as_lan()
    {
        Assert.Equal(NetworkEndpointKind.Lan, NetworkEndpoint.Classify("192.168.1.71", "Wi-Fi"));
        Assert.Equal(NetworkEndpointKind.Lan, NetworkEndpoint.Classify("192.168.38.1", "Ethernet"));
    }

    [Fact]
    public void Classify_marks_hyperv_private_ip_as_other()
    {
        Assert.Equal(
            NetworkEndpointKind.Other,
            NetworkEndpoint.Classify("192.168.177.1", "vEthernet (Default Switch)"));
    }

    [Fact]
    public void PreferredLan_picks_wifi_before_ethernet()
    {
        var list = new[]
        {
            new NetworkEndpoint("192.168.38.1", "Ethernet", NetworkEndpointKind.Lan),
            new NetworkEndpoint("192.168.1.71", "Wi-Fi", NetworkEndpointKind.Lan),
            new NetworkEndpoint("100.87.181.68", "Tailscale", NetworkEndpointKind.Tailscale),
        };

        var preferred = NetworkEndpoint.PreferredLan(list);
        Assert.Equal("192.168.1.71", preferred?.Ip);
    }

    [Fact]
    public void FormatRemaining_shows_mm_ss_then_expired()
    {
        Assert.Equal("4:37", NetworkEndpoint.FormatRemaining(TimeSpan.FromSeconds(277)));
        Assert.Equal("0:05", NetworkEndpoint.FormatRemaining(TimeSpan.FromSeconds(5)));
        Assert.Equal("Expired", NetworkEndpoint.FormatRemaining(TimeSpan.Zero));
        Assert.Equal("Expired", NetworkEndpoint.FormatRemaining(TimeSpan.FromSeconds(-1)));
    }
}
