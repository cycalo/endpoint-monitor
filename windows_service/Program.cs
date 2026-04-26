using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using AspNetCoreRateLimit;
using EndpointMonitorService.Alerts;
using EndpointMonitorService.Browser;
using EndpointMonitorService.Collectors;
using EndpointMonitorService.Commands;
using EndpointMonitorService.Database;
using EndpointMonitorService.Hosted;
using EndpointMonitorService.Options;
using EndpointMonitorService.Services;
using EndpointMonitorService.Sysmon;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseWindowsService();

builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection("Auth"));
builder.Services.Configure<ServerOptions>(builder.Configuration.GetSection("Server"));
builder.Services.Configure<VirusTotalOptions>(builder.Configuration.GetSection("VirusTotal"));
builder.Services.Configure<ThreatIntelOptions>(builder.Configuration.GetSection("ThreatIntel"));
builder.Services.Configure<SoftwareMonitoringOptions>(builder.Configuration.GetSection("SoftwareMonitoring"));

builder.Services.AddMemoryCache();
builder.Services.Configure<IpRateLimitOptions>(builder.Configuration.GetSection("IpRateLimiting"));
builder.Services.Configure<IpRateLimitPolicies>(builder.Configuration.GetSection("IpRateLimitPolicies"));
builder.Services.AddInMemoryRateLimiting();
builder.Services.AddSingleton<IRateLimitConfiguration, RateLimitConfiguration>();

builder.Services.AddSingleton<AppDatabase>();
builder.Services.AddSingleton<WebSocketConnectionManager>();
builder.Services.AddSingleton<PairingAuthService>();
builder.Services.AddSingleton<AuthTokenValidator>();
builder.Services.AddSingleton<ProcessCollector>();
builder.Services.AddSingleton<GeoIpLookupService>();
builder.Services.AddSingleton<NetworkCollector>();
builder.Services.AddSingleton<NetworkThroughputCollector>();
builder.Services.AddSingleton<SystemInfoCollector>();
builder.Services.AddSingleton<BrowserHistoryReader>();
builder.Services.AddSingleton<InstalledSoftwareCollector>();
builder.Services.AddSingleton<ResponseCommandService>();
builder.Services.AddSingleton<AlertEngine>();
builder.Services.AddSingleton<SysmonIngestService>();
builder.Services.AddHttpClient(nameof(SysmonInstaller), client =>
{
    client.Timeout = TimeSpan.FromMinutes(5);
});
builder.Services.AddHttpClient("virustotal", client =>
{
    client.BaseAddress = new Uri("https://www.virustotal.com/api/v3/");
    client.Timeout = TimeSpan.FromSeconds(45);
});
builder.Services.AddHttpClient("threat_intel", client => { client.Timeout = TimeSpan.FromMinutes(2); });
builder.Services.AddSingleton<SysmonInstaller>();
builder.Services.AddSingleton<VirusTotalReputationService>();
builder.Services.AddSingleton<ThreatIntelUpdater>();

builder.Services.AddHostedService<MonitorBroadcastHostedService>();
builder.Services.AddHostedService<SystemInfoHostedService>();
builder.Services.AddHostedService<SysmonHostedService>();
builder.Services.AddHostedService<TrayIconHostedService>();
builder.Services.AddHostedService<FirewallBlockExpiryHostedService>();
builder.Services.AddHostedService<ThreatIntelHostedService>();
builder.Services.AddHostedService<InstalledSoftwareDetectionHostedService>();

var serverOptions = builder.Configuration.GetSection("Server").Get<ServerOptions>() ?? new ServerOptions();
builder.WebHost.ConfigureKestrel(k =>
{
    k.ListenAnyIP(serverOptions.Port);
    if (serverOptions.UseHttps)
        k.ListenAnyIP(serverOptions.HttpsPort, o => o.UseHttps());
});

var app = builder.Build();

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.UseIpRateLimiting();

var db = app.Services.GetRequiredService<AppDatabase>();
await db.InitializeAsync();

app.UseWebSockets();

app.MapPost("/api/auth/pairing/complete", async (HttpContext ctx, PairingCompleteRequest body) =>
{
    if (string.IsNullOrWhiteSpace(body.Code))
        return Results.BadRequest(new { error = "pairing_code_required" });

    var pairing = ctx.RequestServices.GetRequiredService<PairingAuthService>();
    var result = await pairing.ExchangePairingCodeAsync(body.Code, body.DeviceName, ctx.RequestAborted).ConfigureAwait(false);
    if (!result.Success || string.IsNullOrEmpty(result.DeviceToken))
        return Results.Unauthorized();
    return Results.Json(new { token = result.DeviceToken });
});

app.MapGet("/api/auth/devices", async (HttpContext ctx) =>
{
    var auth = ctx.RequestServices.GetRequiredService<AuthTokenValidator>();
    if (!(await auth.TryValidateAuthorizationAsync(ctx.Request.Headers.Authorization, ctx.RequestAborted).ConfigureAwait(false)).Valid)
        return Results.Unauthorized();

    var pairing = ctx.RequestServices.GetRequiredService<PairingAuthService>();
    var devices = await pairing.ListDeviceTokensAsync(ctx.RequestAborted).ConfigureAwait(false);
    return Results.Json(devices.Select(d => new
    {
        id = d.Id,
        deviceName = d.DeviceName,
        createdAt = d.CreatedAt,
        lastUsedAt = d.LastUsedAt,
        revoked = d.Revoked
    }));
});

app.MapPost("/api/auth/devices/revoke", async (HttpContext ctx, RevokeDeviceRequest body) =>
{
    var auth = ctx.RequestServices.GetRequiredService<AuthTokenValidator>();
    if (!(await auth.TryValidateAuthorizationAsync(ctx.Request.Headers.Authorization, ctx.RequestAborted).ConfigureAwait(false)).Valid)
        return Results.Unauthorized();

    if (string.IsNullOrWhiteSpace(body.Id))
        return Results.BadRequest(new { error = "device_id_required" });

    var pairing = ctx.RequestServices.GetRequiredService<PairingAuthService>();
    await pairing.RevokeDeviceTokenAsync(body.Id, ctx.RequestAborted).ConfigureAwait(false);
    return Results.Ok();
});

app.MapGet("/export/events", async (HttpContext ctx, DateTime? from, DateTime? to, string? format) =>
{
    var auth = ctx.RequestServices.GetRequiredService<AuthTokenValidator>();
    if (!(await auth.TryValidateAuthorizationAsync(ctx.Request.Headers.Authorization, ctx.RequestAborted).ConfigureAwait(false)).Valid)
        return Results.Unauthorized();

    var database = ctx.RequestServices.GetRequiredService<AppDatabase>();
    var rows = await database.QuerySysmonAsync(from, to, null, null, 50_000, ctx.RequestAborted).ConfigureAwait(false);
    if (string.Equals(format, "csv", StringComparison.OrdinalIgnoreCase))
    {
        var sb = new StringBuilder();
        sb.AppendLine("eventId,timestamp,type,pid,processName,commandLine,parentPid,remoteAddress,remotePort,dnsQuery");
        foreach (var r in rows)
        {
            sb.AppendLine(string.Join(',', Escape(r.EventId), Escape(r.Timestamp), Escape(r.Type), r.Pid, Escape(r.ProcessName),
                Escape(r.CommandLine), r.ParentPid?.ToString() ?? "", Escape(r.RemoteAddress), r.RemotePort?.ToString() ?? "", Escape(r.DnsQuery)));
        }

        return Results.Text(sb.ToString(), "text/csv");
    }

    return Results.Json(rows);
});

app.Map("/ws", async context =>
{
    if (!context.WebSockets.IsWebSocketRequest)
    {
        context.Response.StatusCode = StatusCodes.Status400BadRequest;
        return;
    }

    var allowed = context.RequestServices.GetRequiredService<IConfiguration>().GetSection("AllowedIpAddresses").Get<string[]>() ?? [];
    if (allowed.Length > 0)
    {
        var ip = context.Connection.RemoteIpAddress?.ToString();
        if (ip != null && !allowed.Contains(ip))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            return;
        }
    }

    var auth = context.RequestServices.GetRequiredService<AuthTokenValidator>();
    if (!(await auth.TryValidateAuthorizationAsync(context.Request.Headers.Authorization, context.RequestAborted).ConfigureAwait(false)).Valid)
    {
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        return;
    }

    var manager = context.RequestServices.GetRequiredService<WebSocketConnectionManager>();
    var dispatcher = context.RequestServices.GetRequiredService<ResponseCommandService>();
    var ws = await context.WebSockets.AcceptWebSocketAsync();
    var id = Guid.NewGuid();
    manager.Add(id, ws);

    var buffer = new byte[1024 * 128];
    try
    {
        while (ws.State == WebSocketState.Open)
        {
            var result = await ws.ReceiveAsync(buffer, context.RequestAborted);
            if (result.MessageType == WebSocketMessageType.Close)
                break;
            if (result.MessageType != WebSocketMessageType.Text)
                continue;

            var json = Encoding.UTF8.GetString(buffer.AsSpan(0, result.Count));
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (!root.TryGetProperty("type", out var typeEl))
                continue;
            var type = typeEl.GetString() ?? "";
            if (type == "ping")
            {
                long? clientTs = null;
                if (root.TryGetProperty("clientTs", out var tsEl) && tsEl.TryGetInt64(out var cts))
                    clientTs = cts;
                // Avoid ternary with two anonymous types — .NET 10 overload resolution picks the wrong Serialize overload.
                string pong;
                if (clientTs.HasValue)
                    pong = JsonSerializer.Serialize(new { type = "pong", clientTs = clientTs.Value }, AppJson.Options);
                else
                    pong = JsonSerializer.Serialize(new { type = "pong", data = (object?)null }, AppJson.Options);
                var bytes = Encoding.UTF8.GetBytes(pong);
                await ws.SendAsync(bytes, WebSocketMessageType.Text, true, context.RequestAborted);
                continue;
            }

            var ip = context.Connection.RemoteIpAddress?.ToString();
            var cmdResult = await dispatcher.HandleAsync(type, root, ip, context.RequestAborted).ConfigureAwait(false);
            var outJson = BuildOutboundJson(type, cmdResult);
            await ws.SendAsync(Encoding.UTF8.GetBytes(outJson), WebSocketMessageType.Text, true, context.RequestAborted).ConfigureAwait(false);
        }
    }
    finally
    {
        manager.Remove(id);
        if (ws.State == WebSocketState.Open)
            await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "", CancellationToken.None);
    }
});

await app.RunAsync();

static string BuildOutboundJson(string originalType, CommandResult r)
{
    if (originalType == "get_browser_history" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "browser_history", data = r.Data }, AppJson.Options);
    if (originalType == "get_installed_software" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "installed_software", data = r.Data }, AppJson.Options);
    if (originalType == "get_firewall_snapshot" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "firewall", data = r.Data }, AppJson.Options);
    if (originalType == "get_flagged_processes" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "flagged_processes", data = r.Data }, AppJson.Options);
    if (originalType == "get_timeline" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "timeline", data = r.Data }, AppJson.Options);
    if (originalType is "get_threat_intel_status" or "refresh_threat_intel" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "threat_intel_status", data = r.Data }, AppJson.Options);
    if (originalType == "get_threat_intel_entries" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "threat_intel_entries", data = r.Data }, AppJson.Options);
    if (originalType == "get_system_info" && r is { Success: true, Data: not null })
        return JsonSerializer.Serialize(new { type = "system_info", data = r.Data }, AppJson.Options);
    return JsonSerializer.Serialize(new
    {
        type = "command_result",
        success = r.Success,
        command = r.Command,
        message = r.Message,
        data = r.Data,
        pid = r.Pid
    }, AppJson.Options);
}

static string Escape(object? o)
{
    var s = o?.ToString() ?? "";
    if (s.Contains(',') || s.Contains('"'))
        return "\"" + s.Replace("\"", "\"\"") + "\"";
    return s;
}

internal sealed record PairingCompleteRequest(string Code, string? DeviceName);
internal sealed record RevokeDeviceRequest(string Id);
