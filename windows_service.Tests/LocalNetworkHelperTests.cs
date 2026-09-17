using System.Net;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Tests;

public sealed class LocalNetworkHelperTests
{
    [Fact]
    public void IsLoopback_returns_true_for_ipv4_loopback()
    {
        Assert.True(LocalNetworkHelper.IsLoopback(IPAddress.Parse("127.0.0.1")));
    }

    [Fact]
    public void IsLoopback_returns_false_for_public_ip()
    {
        Assert.False(LocalNetworkHelper.IsLoopback(IPAddress.Parse("203.0.113.10")));
    }
}
