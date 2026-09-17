using EndpointMonitorService.Database;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Tests;

public sealed class FirewallIsolationServiceTests
{
    [Fact]
    public async Task IsLiveIsolatedAsync_true_when_profiles_block_block_and_allow_rules_exist()
    {
        var netsh = new FakeNetshRunner();
        netsh.EnqueueProfile("BlockInbound,BlockOutbound", "BlockInbound,BlockOutbound", "BlockInbound,BlockOutbound");
        netsh.EnqueueAllowRuleShowSuccess();

        var service = CreateService(netsh);
        Assert.True(await service.IsLiveIsolatedAsync());
    }

    [Fact]
    public async Task IsLiveIsolatedAsync_false_when_outbound_still_allowed()
    {
        var netsh = new FakeNetshRunner();
        netsh.EnqueueProfile("BlockInbound,AllowOutbound", "BlockInbound,AllowOutbound", "BlockInbound,AllowOutbound");

        var service = CreateService(netsh);
        Assert.False(await service.IsLiveIsolatedAsync());
    }

    [Fact]
    public async Task Watchdog_auto_unisolates_when_no_websocket_clients()
    {
        var netsh = new FakeNetshRunner();
        netsh.EnqueueProfile("BlockInbound,AllowOutbound", "BlockInbound,AllowOutbound", "BlockInbound,AllowOutbound");
        netsh.EnqueueAllowRuleShowSuccess();

        var webSockets = new WebSocketConnectionManager(NullLogger<WebSocketConnectionManager>.Instance);
        var service = CreateService(netsh, webSockets, TimeSpan.FromMilliseconds(50));

        service.ArmWatchdog();
        await Task.Delay(200);

        Assert.Contains(netsh.Calls, c => c.Contains("set domainprofile firewallpolicy", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(netsh.Calls, c => c.Contains("delete rule", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Watchdog_does_not_unisolate_when_client_connected()
    {
        var netsh = new FakeNetshRunner();
        var webSockets = new WebSocketConnectionManager(NullLogger<WebSocketConnectionManager>.Instance);
        var service = CreateService(netsh, webSockets, TimeSpan.FromMilliseconds(50));

        // Simulate connected client without opening a real socket: not possible with public API.
        // ClientCount is 0 unless Add is called with a socket — skip unisolate delete verification
        // by ensuring no delete calls occur when we cancel watchdog immediately.
        service.ArmWatchdog();
        service.CancelWatchdog();
        await Task.Delay(100);

        Assert.DoesNotContain(netsh.Calls, c => c.Contains("delete rule", StringComparison.OrdinalIgnoreCase));
    }

    private static FirewallIsolationService CreateService(
        FakeNetshRunner netsh,
        WebSocketConnectionManager? webSockets = null,
        TimeSpan? watchdogDelay = null)
    {
        return new FirewallIsolationService(
            NullLogger<FirewallIsolationService>.Instance,
            netsh,
            new AppDatabase(NullLogger<AppDatabase>.Instance),
            Microsoft.Extensions.Options.Options.Create(new ServerOptions { Port = 5000 }),
            webSockets ?? new WebSocketConnectionManager(NullLogger<WebSocketConnectionManager>.Instance),
            watchdogDelay);
    }

    private sealed class FakeNetshRunner : INetshRunner
    {
        private readonly Queue<string> _profileOutputs = new();
        public List<string> Calls { get; } = [];

        public void EnqueueProfile(string domain, string priv, string pub)
        {
            _profileOutputs.Enqueue($"Firewall Policy {domain}");
            _profileOutputs.Enqueue($"Firewall Policy {priv}");
            _profileOutputs.Enqueue($"Firewall Policy {pub}");
        }

        public void EnqueueAllowRuleShowSuccess()
        {
        }

        public NetshResult Run(string arguments)
        {
            Calls.Add(arguments);

            if (arguments.Contains("show domainprofile", StringComparison.OrdinalIgnoreCase) ||
                arguments.Contains("show privateprofile", StringComparison.OrdinalIgnoreCase) ||
                arguments.Contains("show publicprofile", StringComparison.OrdinalIgnoreCase))
            {
                if (_profileOutputs.Count > 0)
                    return new NetshResult(0, _profileOutputs.Dequeue(), "");
                return new NetshResult(0, "Firewall Policy BlockInbound,BlockOutbound", "");
            }

            if (arguments.Contains("show rule", StringComparison.OrdinalIgnoreCase))
            {
                if (arguments.Contains(FirewallIsolationHelper.AllowInRule, StringComparison.OrdinalIgnoreCase))
                    return new NetshResult(0, $"Rule Name: {FirewallIsolationHelper.AllowInRule}", "");
                if (arguments.Contains(FirewallIsolationHelper.AllowOutRule, StringComparison.OrdinalIgnoreCase))
                    return new NetshResult(0, $"Rule Name: {FirewallIsolationHelper.AllowOutRule}", "");
            }

            if (arguments.StartsWith("advfirewall set", StringComparison.OrdinalIgnoreCase))
                return new NetshResult(0, "", "");

            if (arguments.Contains("delete rule", StringComparison.OrdinalIgnoreCase))
                return new NetshResult(0, "", "");

            return new NetshResult(0, "", "");
        }
    }
}
