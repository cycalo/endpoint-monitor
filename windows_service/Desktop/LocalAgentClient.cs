using System.Net.Http;
using System.Text;
using System.Text.Json;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Desktop;

public sealed class LocalAgentClient : IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly HttpClient _http;
    private readonly int _port;

    public LocalAgentClient(int port)
    {
        _port = port;
        _http = new HttpClient
        {
            BaseAddress = new Uri($"http://127.0.0.1:{port}/"),
            Timeout = TimeSpan.FromSeconds(8),
        };
    }

    public static async Task<bool> IsAgentHealthyAsync(int port, CancellationToken cancellationToken = default)
    {
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
            using var response = await http.GetAsync(
                $"http://127.0.0.1:{port}/health",
                cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
                return false;

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
            using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
            return doc.RootElement.TryGetProperty("service", out var svc)
                && string.Equals(svc.GetString(), "EndpointMonitor", StringComparison.Ordinal);
        }
        catch
        {
            return false;
        }
    }

    public int Port => _port;

    public async Task<LocalStatusDto?> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        return await GetJsonAsync<LocalStatusDto>("/local/status", cancellationToken).ConfigureAwait(false);
    }

    public async Task<LocalPairingDto?> CreatePairingAsync(CancellationToken cancellationToken = default)
    {
        return await GetJsonAsync<LocalPairingDto>("/local/pairing", cancellationToken).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<LocalDeviceDto>> GetDevicesAsync(CancellationToken cancellationToken = default)
    {
        var list = await GetJsonAsync<List<LocalDeviceDto>>("/local/devices", cancellationToken).ConfigureAwait(false);
        return list ?? [];
    }

    public async Task<bool> RevokeDeviceAsync(string id, CancellationToken cancellationToken = default)
    {
        try
        {
            var body = JsonSerializer.Serialize(new { id }, JsonOptions);
            using var content = new StringContent(body, Encoding.UTF8, "application/json");
            using var response = await _http.PostAsync("/local/devices/revoke", content, cancellationToken)
                .ConfigureAwait(false);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    private async Task<T?> GetJsonAsync<T>(string path, CancellationToken cancellationToken)
    {
        try
        {
            using var response = await _http.GetAsync(path, cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
                return default;

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
            return await JsonSerializer.DeserializeAsync<T>(stream, JsonOptions, cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            return default;
        }
    }

    public void Dispose() => _http.Dispose();
}

public sealed class LocalStatusDto
{
    public string Version { get; set; } = "";
    public int HttpPort { get; set; }
    public bool UseHttps { get; set; }
    public int HttpsPort { get; set; }
    public int WebSocketClients { get; set; }
    public bool SysmonInstalled { get; set; }
    public bool ThreatIntelEnabled { get; set; }
    public string? ThreatIntelLastRunUtc { get; set; }
    public string? ThreatIntelLastError { get; set; }
    public int ThreatIntelEntryCount { get; set; }
    public string DataDirectory { get; set; } = "";
    public bool RunningAsAdministrator { get; set; }
    public bool InteractiveSession { get; set; }
    public string[] LanIpv4 { get; set; } = [];
    public NetworkEndpointDto[] Endpoints { get; set; } = [];
}

public sealed class NetworkEndpointDto
{
    public string Ip { get; set; } = "";
    public string Adapter { get; set; } = "";
    public string Kind { get; set; } = "other";
}

public sealed class LocalPairingDto
{
    public string Code { get; set; } = "";
    public DateTime ExpiresAtUtc { get; set; }
    public string[] LanIpv4 { get; set; } = [];
    public NetworkEndpointDto[] Endpoints { get; set; } = [];
    public int HttpPort { get; set; }
}

public sealed class LocalDeviceDto
{
    public string Id { get; set; } = "";
    public string DeviceName { get; set; } = "";
    public string CreatedAt { get; set; } = "";
    public string LastUsedAt { get; set; } = "";
    public bool Revoked { get; set; }
}

public static class LocalStatusMapper
{
    public static LocalStatusDto FromDiagnostics(AgentDiagnostics diag, IReadOnlyList<NetworkEndpoint> endpoints)
    {
        return new LocalStatusDto
        {
            Version = diag.Version,
            HttpPort = diag.HttpPort,
            UseHttps = diag.UseHttps,
            HttpsPort = diag.HttpsPort,
            WebSocketClients = diag.WebSocketClients,
            SysmonInstalled = diag.SysmonInstalled,
            ThreatIntelEnabled = diag.ThreatIntelEnabled,
            ThreatIntelLastRunUtc = diag.ThreatIntelLastRunUtc,
            ThreatIntelLastError = diag.ThreatIntelLastError,
            ThreatIntelEntryCount = diag.ThreatIntelEntryCount,
            DataDirectory = diag.DataDirectory,
            RunningAsAdministrator = diag.RunningAsAdministrator,
            InteractiveSession = diag.InteractiveSession,
            LanIpv4 = endpoints.Select(e => e.Ip).ToArray(),
            Endpoints = ToDtos(endpoints),
        };
    }

    public static NetworkEndpointDto[] ToDtos(IReadOnlyList<NetworkEndpoint> endpoints) =>
        endpoints.Select(e => new NetworkEndpointDto
        {
            Ip = e.Ip,
            Adapter = e.Adapter,
            Kind = e.KindKey,
        }).ToArray();

    public static IReadOnlyList<NetworkEndpoint> FromDtos(IEnumerable<NetworkEndpointDto>? dtos)
    {
        if (dtos == null)
            return [];
        return dtos.Select(d => new NetworkEndpoint(
            d.Ip,
            string.IsNullOrWhiteSpace(d.Adapter) ? "Adapter" : d.Adapter,
            d.Kind switch
            {
                "lan" => NetworkEndpointKind.Lan,
                "tailscale" => NetworkEndpointKind.Tailscale,
                _ => NetworkEndpointKind.Other,
            })).ToList();
    }
}
