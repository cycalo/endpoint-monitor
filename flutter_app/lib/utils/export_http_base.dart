/// Derives REST base URL from WebSocket host (e.g. `192.168.1.10:5000` or `ws://host/ws`).
String httpBaseFromMonitorHost(String raw) {
  var h = raw.trim();
  if (h.isEmpty) return 'http://127.0.0.1:5000';
  if (h.startsWith('ws://')) {
    h = 'http://${h.substring(5)}';
  } else if (h.startsWith('wss://')) {
    h = 'https://${h.substring(6)}';
  } else if (!h.startsWith('http://') && !h.startsWith('https://')) {
    h = 'http://$h';
  }
  h = h.split('/ws').first;
  if (h.endsWith('/')) h = h.substring(0, h.length - 1);
  final uri = Uri.parse(h);
  if (!uri.hasPort) {
    h = uri.replace(port: 5000).toString();
  }
  return h;
}
