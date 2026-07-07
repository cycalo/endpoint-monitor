using System.Collections.Concurrent;
using System.Net.WebSockets;

namespace EndpointMonitorService.Services;

public sealed class WebSocketConnectionManager(ILogger<WebSocketConnectionManager> logger)
{
    private readonly ConcurrentDictionary<Guid, WebSocket> _clients = new();

    public int ClientCount => _clients.Count;

    public IReadOnlyCollection<WebSocket> Clients => _clients.Values.ToArray();

    public void Add(Guid id, WebSocket socket)
    {
        if (_clients.TryAdd(id, socket))
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
            var socket = kv.Value;
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
        if (!_clients.TryGetValue(id, out var socket) || socket.State != WebSocketState.Open)
            return;
        await socket.SendAsync(payload, WebSocketMessageType.Text, true, cancellationToken).ConfigureAwait(false);
    }
}
