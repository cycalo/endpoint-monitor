using EndpointMonitorService.Options;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Tests;

public sealed class FirewallIsolationHelperTests
{
    [Fact]
    public void TryParsePolicyLine_parses_block_allow_default()
    {
        const string output = """
            Domain Profile Settings:
            -------------------------------------------------------------------
            State                                 ON
            Firewall Policy                       BlockInbound,AllowOutbound
            """;

        Assert.True(FirewallIsolationHelper.TryParsePolicyLine(output, out var inbound, out var outbound));
        Assert.Equal("BlockInbound", inbound);
        Assert.Equal("AllowOutbound", outbound);
    }

    [Fact]
    public void TryParsePolicyLine_parses_block_block_isolation()
    {
        const string output = "Firewall Policy    BlockInbound,BlockOutbound";

        Assert.True(FirewallIsolationHelper.TryParsePolicyLine(output, out var inbound, out var outbound));
        Assert.Equal("BlockInbound", inbound);
        Assert.Equal("BlockOutbound", outbound);
        Assert.True(FirewallIsolationHelper.IsBlockBlockPolicy(inbound, outbound));
    }

    [Fact]
    public void FormatLocalPorts_includes_https_when_enabled()
    {
        var ports = FirewallIsolationHelper.FormatLocalPorts(new ServerOptions
        {
            Port = 5000,
            UseHttps = true,
            HttpsPort = 5001,
        });

        Assert.Equal("5000,5001", ports);
    }

    [Fact]
    public void FormatLocalPorts_http_only_by_default()
    {
        var ports = FirewallIsolationHelper.FormatLocalPorts(new ServerOptions { Port = 5000 });
        Assert.Equal("5000", ports);
    }

    [Fact]
    public void RuleOutputContainsName_matches_rule_header()
    {
        const string output = """
            Rule Name:                            EM_ISOLATE_ALLOW_MONITOR_IN
            Enabled:                              Yes
            """;

        Assert.True(FirewallIsolationHelper.RuleOutputContainsName(
            output,
            FirewallIsolationHelper.AllowInRule));
    }
}
