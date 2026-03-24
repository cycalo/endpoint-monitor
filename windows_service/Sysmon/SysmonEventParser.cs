using System.Diagnostics.Eventing.Reader;
using System.Xml.Linq;
using EndpointMonitorService.Models;

namespace EndpointMonitorService.Sysmon;

public static class SysmonEventParser
{
    public static SysmonEvent? TryParse(EventRecord record)
    {
        if (record.Id is not (1 or 3 or 5 or 22))
            return null;

        string xml;
        try
        {
            xml = record.ToXml();
        }
        catch
        {
            return null;
        }

        var doc = XDocument.Parse(xml);
        var ns = doc.Root?.GetDefaultNamespace() ?? XNamespace.None;
        var data = doc.Descendants(ns + "Data")
            .Select(e => new { Name = e.Attribute("Name")?.Value, Value = e.Value })
            .Where(x => x.Name != null)
            .ToDictionary(x => x.Name!, x => x.Value, StringComparer.OrdinalIgnoreCase);

        string Get(string key) => data.TryGetValue(key, out var v) ? v : "";

        var ts = record.TimeCreated?.ToUniversalTime().ToString("O") ?? DateTime.UtcNow.ToString("O");

        return record.Id switch
        {
            1 => new SysmonEvent
            {
                EventId = 1,
                Timestamp = ts,
                Type = "ProcessCreate",
                Pid = ParseInt(Get("ProcessId")),
                ProcessName = Path.GetFileName(Get("Image").Trim()),
                CommandLine = NullIfEmpty(Get("CommandLine")),
                ParentPid = ParseIntNullable(Get("ParentProcessId")),
                RemoteAddress = null,
                RemotePort = null,
                DnsQuery = null,
                RawXml = xml
            },
            3 => new SysmonEvent
            {
                EventId = 3,
                Timestamp = ts,
                Type = "NetworkConnect",
                Pid = ParseInt(Get("ProcessId")),
                ProcessName = Path.GetFileName(Get("Image").Trim()),
                CommandLine = null,
                ParentPid = null,
                RemoteAddress = NullIfEmpty(Get("DestinationIp")),
                RemotePort = ParseIntNullable(Get("DestinationPort")),
                DnsQuery = null,
                RawXml = xml
            },
            5 => new SysmonEvent
            {
                EventId = 5,
                Timestamp = ts,
                Type = "ProcessTerminate",
                Pid = ParseInt(Get("ProcessId")),
                ProcessName = Path.GetFileName(Get("Image").Trim()),
                CommandLine = null,
                ParentPid = null,
                RemoteAddress = null,
                RemotePort = null,
                DnsQuery = null,
                RawXml = xml
            },
            22 => new SysmonEvent
            {
                EventId = 22,
                Timestamp = ts,
                Type = "DnsQuery",
                Pid = ParseInt(Get("ProcessId")),
                ProcessName = Path.GetFileName(Get("Image").Trim()),
                CommandLine = null,
                ParentPid = null,
                RemoteAddress = null,
                RemotePort = null,
                DnsQuery = NullIfEmpty(Get("QueryName")),
                RawXml = xml
            },
            _ => null
        };
    }

    private static int ParseInt(string s) => int.TryParse(s, out var v) ? v : 0;

    private static int? ParseIntNullable(string s) => int.TryParse(s, out var v) ? v : null;

    private static string? NullIfEmpty(string s) => string.IsNullOrWhiteSpace(s) ? null : s;
}
