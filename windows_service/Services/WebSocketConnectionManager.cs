using System.Collections.Concurrent;
using System.Net.WebSockets;

namespace EndpointMonitorService.Services;

public readonly record struct LiveWebSocketClient(string DeviceId, string RemoteIp);

public sealed class WebSocketConnectionManager(ILogger<WebSocketConnectionManager> logger)
{
    private readonly ConcurrentDictionary<Guid, ClientSlot> _clients = new();

    public int ClientCount => _clients.Count;

    public IReadOnlyCollection<WebSocket> Clients => _clients.Values.Select(slot => slot.Socket).ToArray();

    public IReadOnlyList<LiveWebSocketClient> LiveClients =>
        _clients.Values
            .Where(slot => slot.Socket.State == WebSocketState.Open && !string.IsNullOrEmpty(slot.DeviceId))
            .Select(slot => new LiveWebSocketClient(slot.DeviceId!, slot.RemoteIp ?? ""))
            .ToArray();

    public void Add(Guid id, WebSocket socket, string? deviceId = null, string? remoteIp = null)
    {
        var slot = new ClientSlot(socket, string.IsNullOrWhiteSpace(deviceId) ? null : deviceId, remoteIp);
        if (_clients.TryAdd(id, slot))
            logger.LogInformation("WebSocket client connected: {Id}", id);
    }

    public void Remove(Guid id)
    {
        if (_clients.TryRemove(id, out _))
            logger.LogInformation("WebSocket client disconnected: {Id}", id);
    }

    public async Task BroadcastAsync(ReadOnlyMemory<byte> payload, CancellationToken cancellationToken = default)
    {
        if (_clients.IsEmpty)
            return;

        foreach (var kv in _clients)
        {
            var socket = kv.Value.Socket;
            if (socket.State != WebSocketState.Open)
                continue;
            try
            {
                await socket.SendAsync(payload, WebSocketMessageType.Text, true, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Broadcast failed for client {Id}", kv.Key);
            }
        }
    }

    public async Task SendToAsync(Guid id, ReadOnlyMemory<byte> payload, CancellationToken cancellationToken = default)
    {
        if (!_clients.TryGetValue(id, out var slot) || slot.Socket.State != WebSocketState.Open)
            return;
        await slot.Socket.SendAsync(payload, WebSocketMessageType.Text, true, cancellationToken).ConfigureAwait(false);
    }

    private sealed record ClientSlot(WebSocket Socket, string? DeviceId, string? RemoteIp);
}
