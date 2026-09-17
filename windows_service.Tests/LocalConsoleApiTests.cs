using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using EndpointMonitorService.Desktop;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace EndpointMonitorService.Tests;

public sealed class LocalConsoleApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public LocalConsoleApiTests(WebApplicationFactory<Program> factory)
    {
        Environment.SetEnvironmentVariable("DOTNET_ENVIRONMENT", "Testing");
        _factory = factory.WithWebHostBuilder(builder => builder.UseEnvironment("Testing"));
    }

    [Fact]
    public async Task Local_pairing_returns_shape_without_secrets()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/local/pairing");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(json.TryGetProperty("code", out var code));
        Assert.Equal(6, code.GetString()?.Length);
        Assert.True(json.TryGetProperty("expiresAtUtc", out _));
        Assert.True(json.TryGetProperty("lanIpv4", out _));
        Assert.True(json.TryGetProperty("endpoints", out var endpoints));
        Assert.Equal(JsonValueKind.Array, endpoints.ValueKind);
        Assert.True(json.TryGetProperty("httpPort", out _));
        Assert.False(json.TryGetProperty("token", out _));
    }

    [Fact]
    public async Task Local_devices_returns_array()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/local/devices");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var devices = await response.Content.ReadFromJsonAsync<List<LocalDeviceDto>>();
        Assert.NotNull(devices);
    }

    [Fact]
    public async Task Local_revoke_rejects_empty_id()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/local/devices/revoke", new { id = "" });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
