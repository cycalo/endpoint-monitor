using EndpointMonitorService.Desktop;
using EndpointMonitorService.Database;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using EndpointMonitorService.Sysmon;
using Microsoft.Extensions.Options;

namespace EndpointMonitorService;

internal static class LocalConsoleApi
{
    internal static void MapLocalConsoleEndpoints(WebApplication app)
    {
        app.MapGet("/local/status", async (HttpContext ctx) =>
        {
            if (!LocalNetworkHelper.IsLoopbackRequest(ctx))
                return Results.StatusCode(StatusCodes.Status403Forbidden);

            var diag = await BuildDiagnosticsAsync(ctx).ConfigureAwait(false);
            var endpoints = LocalNetworkHelper.GetNetworkEndpoints();
            return Results.Json(LocalStatusMapper.FromDiagnostics(diag, endpoints));
        });

        app.MapGet("/local/pairing", (HttpContext ctx, PairingAuthService pairing) =>
        {
            if (!LocalNetworkHelper.IsLoopbackRequest(ctx))
                return Results.StatusCode(StatusCodes.Status403Forbidden);

            try
            {
                var (code, expiresAtUtc) = pairing.CreatePairingCode(TimeSpan.FromMinutes(5));
                var port = ctx.RequestServices.GetRequiredService<IOptions<ServerOptions>>().Value.Port;
                var endpoints = LocalNetworkHelper.GetNetworkEndpoints();
                return Results.Json(new
                {
                    code,
                    expiresAtUtc,
                    lanIpv4 = endpoints.Select(e => e.Ip),
                    endpoints = LocalStatusMapper.ToDtos(endpoints),
                    httpPort = port,
                });
            }
            catch (InvalidOperationException)
            {
                return Results.Json(new { error = "pairing_unavailable" }, statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        });

        app.MapGet("/local/devices", async (HttpContext ctx) =>
        {
            if (!LocalNetworkHelper.IsLoopbackRequest(ctx))
                return Results.StatusCode(StatusCodes.Status403Forbidden);

            var pairing = ctx.RequestServices.GetRequiredService<PairingAuthService>();
            var devices = await pairing.ListDeviceTokensAsync(ctx.RequestAborted).ConfigureAwait(false);
            return Results.Json(devices.Select(d => new
            {
                id = d.Id,
                deviceName = d.DeviceName,
                createdAt = d.CreatedAt,
                lastUsedAt = d.LastUsedAt,
                revoked = d.Revoked,
            }));
        });

        app.MapPost("/local/devices/revoke", async (HttpContext ctx, LocalRevokeDeviceRequest body) =>
        {
            if (!LocalNetworkHelper.IsLoopbackRequest(ctx))
                return Results.StatusCode(StatusCodes.Status403Forbidden);

            if (string.IsNullOrWhiteSpace(body.Id) || body.Id.Length > 128)
                return Results.BadRequest(new { error = "device_id_required" });

            var pairing = ctx.RequestServices.GetRequiredService<PairingAuthService>();
            await pairing.RevokeDeviceTokenAsync(body.Id.Trim(), ctx.RequestAborted).ConfigureAwait(false);
            return Results.Ok();
        });
    }

    private static async Task<AgentDiagnostics> BuildDiagnosticsAsync(HttpContext ctx)
    {
        var server = ctx.RequestServices.GetRequiredService<IOptions<ServerOptions>>().Value;
        var threatIntel = ctx.RequestServices.GetRequiredService<IOptions<ThreatIntelOptions>>().Value;
        var ws = ctx.RequestServices.GetRequiredService<WebSocketConnectionManager>();
        var sysmon = ctx.RequestServices.GetRequiredService<SysmonInstaller>();
        var intel = ctx.RequestServices.GetRequiredService<ThreatIntelUpdater>();
        var database = ctx.RequestServices.GetRequiredService<AppDatabase>();

        int entryCount;
        try
        {
            entryCount = (await database.GetActiveBadIpsAsync(ctx.RequestAborted).ConfigureAwait(false)).Count;
        }
        catch
        {
            entryCount = 0;
        }

        return AgentDiagnosticsBuilder.Build(server, threatIntel, ws, sysmon, intel, entryCount);
    }
}

internal sealed record LocalRevokeDeviceRequest(string Id);
