using EndpointMonitorService.Desktop;

namespace EndpointMonitorService.Tests;

public sealed class ConsoleFormatTests
{
    [Theory]
    [InlineData("Pixel 8", DevicePlatform.Android)]
    [InlineData("Samsung Galaxy", DevicePlatform.Android)]
    [InlineData("iPhone 15", DevicePlatform.Ios)]
    [InlineData("iPad Pro", DevicePlatform.Ios)]
    [InlineData("DESKTOP-ABC", DevicePlatform.Windows)]
    [InlineData("Office Windows PC", DevicePlatform.Windows)]
    [InlineData("Michael's phone", DevicePlatform.Unknown)]
    public void PlatformOf_classifies_common_names(string name, DevicePlatform expected)
    {
        Assert.Equal(expected, ConsoleFormat.PlatformOf(name));
        Assert.False(string.IsNullOrWhiteSpace(ConsoleFormat.PlatformLabel(ConsoleFormat.PlatformOf(name))));
    }

    [Fact]
    public void IsLiveSession_matches_device_id_ignoring_case()
    {
        Assert.True(ConsoleFormat.IsLiveSession("AbC", ["abc"]));
        Assert.False(ConsoleFormat.IsLiveSession("abc", ["other"]));
        Assert.False(ConsoleFormat.IsLiveSession("", ["abc"]));
        Assert.False(ConsoleFormat.IsLiveSession("abc", null));
    }

    [Fact]
    public void FormatAgentVersion_prefixes_a_single_v()
    {
        Assert.Equal("Agent v1.0.0", ConsoleFormat.FormatAgentVersion("1.0.0"));
        Assert.Equal("Agent v1.2.3", ConsoleFormat.FormatAgentVersion("v1.2.3"));
        Assert.Equal("Agent -", ConsoleFormat.FormatAgentVersion(null));
        Assert.Equal("Agent -", ConsoleFormat.FormatAgentVersion(" \n "));
    }

    [Fact]
    public void FormatHostUptime_uses_the_largest_useful_units()
    {
        Assert.Equal("0m", ConsoleFormat.FormatHostUptime(TimeSpan.FromSeconds(-5)));
        Assert.Equal("45m", ConsoleFormat.FormatHostUptime(TimeSpan.FromMinutes(45)));
        Assert.Equal("2h 5m", ConsoleFormat.FormatHostUptime(TimeSpan.FromHours(2) + TimeSpan.FromMinutes(5)));
        Assert.Equal("1d 3h 4m", ConsoleFormat.FormatHostUptime(TimeSpan.FromDays(1) + TimeSpan.FromHours(3) + TimeSpan.FromMinutes(4)));
    }

    [Fact]
    public void SafeInline_strips_controls_and_limits_length()
    {
        Assert.Equal("ab", ConsoleFormat.SafeInline("a\nb\r", 8));
        Assert.Equal("abcd", ConsoleFormat.SafeInline("abcdef", 4));
        Assert.Equal("", ConsoleFormat.SafeInline("   ", 8));
    }
}
