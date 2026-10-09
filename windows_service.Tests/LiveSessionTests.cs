using System.Net.WebSockets;
using EndpointMonitorService.Desktop;
using EndpointMonitorService.Services;
using Microsoft.Extensions.Logging.Abstractions;

namespace EndpointMonitorService.Tests;

public sealed class LiveSessionTests
{
    [Fact]
    public void LiveClients_reports_open_sockets_that_have_a_device_id()
    {
        var manager = new WebSocketConnectionManager(NullLogger<WebSocketConnectionManager>.Instance);
        Assert.Empty(manager.LiveClients);

        manager.Add(Guid.NewGuid(), new OpenSocket(), "device-1", "192.168.1.20");
        manager.Add(Guid.NewGuid(), new OpenSocket());

        Assert.Equal(2, manager.ClientCount);
        var live = Assert.Single(manager.LiveClients);
        Assert.Equal("device-1", live.DeviceId);
        Assert.Equal("192.168.1.20", live.RemoteIp);
    }

    [Fact]
    public void ApplyLiveClients_drops_blank_or_overlong_ids_and_sanitizes_ips()
    {
        var dto = new LocalStatusDto();
        LocalStatusMapper.ApplyLiveClients(dto,
        [
            new LiveWebSocketClient("abc", "10.0.0.2"),
            new LiveWebSocketClient("", "10.0.0.3"),
            new LiveWebSocketClient(new string('x', 80), "10.0.0.4"),
            new LiveWebSocketClient("ok", "10.1.1.1\nextra"),
        ]);

        Assert.Equal(2, dto.LiveClients.Length);
        Assert.Equal("abc", dto.LiveClients[0].DeviceId);
        Assert.Equal("10.0.0.2", dto.LiveClients[0].RemoteIp);
        Assert.Equal("ok", dto.LiveClients[1].DeviceId);
        Assert.Equal("10.1.1.1extra", dto.LiveClients[1].RemoteIp);
    }

    private sealed class OpenSocket : WebSocket
    {
        public override WebSocketCloseStatus? CloseStatus => null;
        public override string? CloseStatusDescription => null;
        public override WebSocketState State => WebSocketState.Open;
        public override string? SubProtocol => null;
        public override void Abort() { }
        public override Task CloseAsync(WebSocketCloseStatus closeStatus, string? statusDescription, CancellationToken cancellationToken) => Task.CompletedTask;
        public override Task CloseOutputAsync(WebSocketCloseStatus closeStatus, string? statusDescription, CancellationToken cancellationToken) => Task.CompletedTask;
        public override void Dispose() { }
        public override Task<WebSocketReceiveResult> ReceiveAsync(ArraySegment<byte> buffer, CancellationToken cancellationToken) => throw new NotSupportedException();
        public override Task SendAsync(ArraySegment<byte> buffer, WebSocketMessageType messageType, bool endOfMessage, CancellationToken cancellationToken) => Task.CompletedTask;
    }
}
