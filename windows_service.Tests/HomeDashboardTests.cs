using EndpointMonitorService.Desktop;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Tests;

public sealed class HomeDashboardTests
{
    [Fact]
    public void WifiReady_is_true_only_when_a_lan_endpoint_exists()
    {
        var endpoints = new[]
        {
            new NetworkEndpoint("100.87.181.68", "Tailscale", NetworkEndpointKind.Tailscale),
            new NetworkEndpoint("192.168.177.1", "vEthernet", NetworkEndpointKind.Other),
        };
        Assert.False(HomeDashboard.WifiReady(endpoints));

        var withLan = endpoints.Append(
            new NetworkEndpoint("192.168.1.71", "Wi-Fi", NetworkEndpointKind.Lan)).ToArray();
        Assert.True(HomeDashboard.WifiReady(withLan));
    }

    [Fact]
    public void TailscaleConnected_is_true_only_when_a_tailscale_endpoint_exists()
    {
        var lanOnly = new[]
        {
            new NetworkEndpoint("192.168.1.71", "Wi-Fi", NetworkEndpointKind.Lan),
        };
        Assert.False(HomeDashboard.TailscaleConnected(lanOnly));
        Assert.True(HomeDashboard.TailscaleConnected(
        [
            new NetworkEndpoint("100.87.181.68", "Tailscale", NetworkEndpointKind.Tailscale),
        ]));
    }

    [Fact]
    public void NextStep_when_agent_unreachable_hides_actions()
    {
        var step = HomeDashboard.NextStep(agentReachable: false, pairedCount: 2, connectedPhones: 1);
        Assert.Equal("Agent unreachable", step.Title);
        Assert.False(step.ShowPair);
        Assert.False(step.ShowDevices);
        Assert.Contains("Windows service", step.Body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void NextStep_when_no_devices_prompts_pairing()
    {
        var step = HomeDashboard.NextStep(agentReachable: true, pairedCount: 0, connectedPhones: 0);
        Assert.Equal("Pair a phone", step.Title);
        Assert.True(step.ShowPair);
        Assert.False(step.ShowDevices);
        Assert.Contains("Pair", step.Body, StringComparison.Ordinal);
    }

    [Fact]
    public void NextStep_when_paired_but_not_connected_points_to_devices()
    {
        var step = HomeDashboard.NextStep(agentReachable: true, pairedCount: 2, connectedPhones: 0);
        Assert.Equal("Waiting for a phone", step.Title);
        Assert.True(step.ShowPair);
        Assert.True(step.ShowDevices);
    }

    [Fact]
    public void NextStep_when_connected_is_set_up()
    {
        var step = HomeDashboard.NextStep(agentReachable: true, pairedCount: 2, connectedPhones: 1);
        Assert.Equal("You're set up", step.Title);
        Assert.True(step.ShowPair);
        Assert.True(step.ShowDevices);
        Assert.Contains("connected", step.Body, StringComparison.OrdinalIgnoreCase);
    }
}
