using System.Reflection;
using System.Text;
using System.Xml.Linq;
using EndpointMonitorService.Sysmon;

namespace EndpointMonitorService.Tests;

public sealed class SysmonConfigResourceTests
{
    [Fact]
    public void Bundled_config_is_embedded_sysmon_xml()
    {
        var assembly = typeof(SysmonInstaller).Assembly;
        using var stream = assembly.GetManifestResourceStream(
            "EndpointMonitorService.Sysmon.sysmonconfig-export.xml");

        Assert.NotNull(stream);
        using var reader = new StreamReader(stream, Encoding.UTF8);
        var xml = reader.ReadToEnd();
        var doc = XDocument.Parse(xml);

        Assert.Equal("Sysmon", doc.Root?.Name.LocalName);
        Assert.Contains("SwiftOnSecurity/sysmon-config", xml, StringComparison.Ordinal);
    }
}
