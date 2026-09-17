using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace EndpointMonitorService.Services;

/// <summary>Builds the endpointmonitor://pair QR payload from pairing state.</summary>
public static class PairingQrPayload
{
    private const int DefaultHttpPort = 5000;
    private const string UriPrefix = "endpointmonitor://pair?data=";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public static string BuildUri(
        string code,
        DateTime expiresAtUtc,
        IReadOnlyList<NetworkEndpoint> endpoints,
        int httpPort)
    {
        var port = httpPort > 0 ? httpPort : DefaultHttpPort;
        var hosts = BuildHosts(endpoints, port);
        var expiry = expiresAtUtc.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(expiresAtUtc, DateTimeKind.Utc)
            : expiresAtUtc.ToUniversalTime();

        var payload = new PairingQrJson
        {
            V = 1,
            Code = code,
            Hosts = hosts,
            ExpiresAt = expiry.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"),
        };

        var json = JsonSerializer.Serialize(payload, JsonOptions);
        var data = Base64UrlEncode(Encoding.UTF8.GetBytes(json));
        return UriPrefix + data;
    }

    private static IReadOnlyList<string> BuildHosts(
        IReadOnlyList<NetworkEndpoint> endpoints,
        int httpPort)
    {
        var port = httpPort > 0 ? httpPort : DefaultHttpPort;
        var hosts = new List<string>();
        foreach (var endpoint in endpoints)
        {
            if (endpoint.Kind is not (NetworkEndpointKind.Lan or NetworkEndpointKind.Tailscale))
                continue;
            if (string.IsNullOrWhiteSpace(endpoint.Ip))
                continue;
            hosts.Add($"http://{endpoint.Ip}:{port}");
        }
        return hosts;
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private sealed class PairingQrJson
    {
        public int V { get; set; }
        public string Code { get; set; } = "";
        public IReadOnlyList<string> Hosts { get; set; } = [];
        public string ExpiresAt { get; set; } = "";
    }
}
