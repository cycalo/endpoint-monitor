using EndpointMonitorService.Database;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using EndpointMonitorService.Sysmon;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService.Desktop;

/// <summary>Unified data access for WPF pages — HTTP in UI-only mode, DI in in-process mode.</summary>
public sealed class AgentDataService : IDisposable
{
    private readonly bool _uiOnly;
    private readonly LocalAgentClient? _client;
    private readonly IServiceProvider? _services;

    public AgentDataService(int port)
    {
        _uiOnly = true;
        _client = new LocalAgentClient(port);
    }

    public AgentDataService(IServiceProvider services)
    {
        _uiOnly = false;
        _services = services;
    }

    public bool IsUiOnly => _uiOnly;

    public async Task<LocalStatusDto?> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        if (_uiOnly)
            return await _client!.GetStatusAsync(cancellationToken).ConfigureAwait(false);

        return await Task.Run(() => BuildStatusInProcess(), cancellationToken).ConfigureAwait(false);
    }

    public async Task<LocalPairingDto?> CreatePairingAsync(CancellationToken cancellationToken = default)
    {
        if (_uiOnly)
            return await _client!.CreatePairingAsync(cancellationToken).ConfigureAwait(false);

        return await Task.Run(CreatePairingInProcess, cancellationToken).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<LocalDeviceDto>> GetDevicesAsync(CancellationToken cancellationToken = default)
    {
        if (_uiOnly)
            return await _client!.GetDevicesAsync(cancellationToken).ConfigureAwait(false);

        return await Task.Run(ListDevicesInProcess, cancellationToken).ConfigureAwait(false);
    }

    public async Task<bool> RevokeDeviceAsync(string id, CancellationToken cancellationToken = default)
    {
        if (_uiOnly)
            return await _client!.RevokeDeviceAsync(id, cancellationToken).ConfigureAwait(false);

        try
        {
            var pairing = _services!.GetRequiredService<PairingAuthService>();
            await pairing.RevokeDeviceTokenAsync(id, cancellationToken).ConfigureAwait(false);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private LocalStatusDto BuildStatusInProcess()
    {
        var server = _services!.GetRequiredService<IOptions<ServerOptions>>().Value;
        var threatIntel = _services!.GetRequiredService<IOptions<ThreatIntelOptions>>().Value;
        var ws = _services!.GetRequiredService<WebSocketConnectionManager>();
        var sysmon = _services!.GetRequiredService<SysmonInstaller>();
        var intel = _services!.GetRequiredService<ThreatIntelUpdater>();
        var database = _services!.GetRequiredService<AppDatabase>();

        int entryCount;
        try
        {
            entryCount = database.GetActiveBadIpsAsync(CancellationToken.None)
                .ConfigureAwait(false).GetAwaiter().GetResult().Count;
        }
        catch
        {
            entryCount = 0;
        }

        var diag = AgentDiagnosticsBuilder.Build(server, threatIntel, ws, sysmon, intel, entryCount);
        var endpoints = LocalNetworkHelper.GetNetworkEndpoints();
        return LocalStatusMapper.FromDiagnostics(diag, endpoints);
    }

    private LocalPairingDto CreatePairingInProcess()
    {
        var pairing = _services!.GetRequiredService<PairingAuthService>();
        var port = _services!.GetRequiredService<IOptions<ServerOptions>>().Value.Port;
        var (code, expiresAtUtc) = pairing.CreatePairingCode(TimeSpan.FromMinutes(5));
        var endpoints = LocalNetworkHelper.GetNetworkEndpoints();
        return new LocalPairingDto
        {
            Code = code,
            ExpiresAtUtc = expiresAtUtc,
            LanIpv4 = endpoints.Select(e => e.Ip).ToArray(),
            Endpoints = LocalStatusMapper.ToDtos(endpoints),
            HttpPort = port,
        };
    }

    private IReadOnlyList<LocalDeviceDto> ListDevicesInProcess()
    {
        var pairing = _services!.GetRequiredService<PairingAuthService>();
        var devices = pairing.ListDeviceTokensAsync(CancellationToken.None)
            .ConfigureAwait(false).GetAwaiter().GetResult();
        return devices.Select(d => new LocalDeviceDto
        {
            Id = d.Id,
            DeviceName = d.DeviceName,
            CreatedAt = d.CreatedAt,
            LastUsedAt = d.LastUsedAt,
            Revoked = d.Revoked,
        }).ToList();
    }

    public void Dispose() => _client?.Dispose();
}
