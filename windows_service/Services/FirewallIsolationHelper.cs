using System.Reflection;
using System.Text.RegularExpressions;
using EndpointMonitorService.Options;

namespace EndpointMonitorService.Services;

public enum FirewallProfileKind
{
    Domain,
    Private,
    Public,
}

public sealed record FirewallProfilePolicy(string Inbound, string Outbound)
{
    public string ToNetshArgument() =>
        $"{Inbound.ToLowerInvariant()},{Outbound.ToLowerInvariant()}";
}

public static partial class FirewallIsolationHelper
{
    public const string AllowInRule = "EM_ISOLATE_ALLOW_MONITOR_IN";
    public const string AllowOutRule = "EM_ISOLATE_ALLOW_MONITOR_OUT";

    public static readonly string[] LegacyRuleNames =
    [
        "EM_ISOLATE_BLOCK_IN",
        "EM_ISOLATE_BLOCK_OUT",
        "EM_ISOLATE_ALLOW_MONITOR",
        "EM_ISOLATE_ALLOW_MONITOR_OUT",
    ];

    public static string ProfileNetshName(FirewallProfileKind profile) => profile switch
    {
        FirewallProfileKind.Domain => "domainprofile",
        FirewallProfileKind.Private => "privateprofile",
        FirewallProfileKind.Public => "publicprofile",
        _ => throw new ArgumentOutOfRangeException(nameof(profile)),
    };

    public static bool TryParsePolicyLine(string netshOutput, out string inbound, out string outbound)
    {
        inbound = "";
        outbound = "";
        if (string.IsNullOrWhiteSpace(netshOutput))
            return false;

        foreach (var rawLine in netshOutput.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries))
        {
            var line = rawLine.Trim();
            var match = FirewallPolicyLine().Match(line);
            if (!match.Success)
                continue;
            inbound = NormalizeInboundToken(match.Groups[1].Value);
            outbound = NormalizeOutboundToken(match.Groups[2].Value);
            return inbound.Length > 0 && outbound.Length > 0;
        }

        return false;
    }

    public static bool IsBlockBlockPolicy(string inbound, string outbound) =>
        string.Equals(inbound, "BlockInbound", StringComparison.OrdinalIgnoreCase) &&
        string.Equals(outbound, "BlockOutbound", StringComparison.OrdinalIgnoreCase);

    public static bool IsBlockBlockPolicy(FirewallProfilePolicy policy) =>
        IsBlockBlockPolicy(policy.Inbound, policy.Outbound);

    public static string FormatLocalPorts(ServerOptions options)
    {
        var ports = new List<int> { options.Port };
        if (options.UseHttps && options.HttpsPort > 0 && options.HttpsPort != options.Port)
            ports.Add(options.HttpsPort);
        return string.Join(',', ports.Distinct().OrderBy(p => p));
    }

    /// <summary>
    /// Resolves the service executable for firewall program= rules. Returns null for dotnet-hosted dev runs.
    /// </summary>
    public static string? ResolveServiceExecutablePath()
    {
        var processPath = Environment.ProcessPath;
        if (!string.IsNullOrEmpty(processPath)
            && processPath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(Path.GetFileName(processPath), "dotnet.exe", StringComparison.OrdinalIgnoreCase))
        {
            return processPath;
        }

        var loc = Assembly.GetExecutingAssembly().Location;
        if (string.IsNullOrEmpty(loc))
            return null;

        var dir = Path.GetDirectoryName(loc);
        if (string.IsNullOrEmpty(dir))
            return null;

        var baseName = Path.GetFileNameWithoutExtension(loc);
        var candidate = Path.Combine(dir, baseName + ".exe");
        return File.Exists(candidate) ? candidate : null;
    }

    public static string EscapeProgramPath(string path) =>
        path.Replace("\"", "\\\"", StringComparison.Ordinal);

    public static bool RuleOutputContainsName(string showOutput, string ruleName) =>
        showOutput.Contains(ruleName, StringComparison.OrdinalIgnoreCase);

    private static string NormalizeInboundToken(string raw)
    {
        var token = raw.Trim();
        if (token.Equals("BlockInbound", StringComparison.OrdinalIgnoreCase))
            return "BlockInbound";
        if (token.Equals("AllowInbound", StringComparison.OrdinalIgnoreCase))
            return "AllowInbound";
        return token;
    }

    private static string NormalizeOutboundToken(string raw)
    {
        var token = raw.Trim();
        if (token.Equals("BlockOutbound", StringComparison.OrdinalIgnoreCase))
            return "BlockOutbound";
        if (token.Equals("AllowOutbound", StringComparison.OrdinalIgnoreCase))
            return "AllowOutbound";
        return token;
    }

    [GeneratedRegex(@"Firewall\s+Policy\s+(\w+)\s*,\s*(\w+)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex FirewallPolicyLine();
}
