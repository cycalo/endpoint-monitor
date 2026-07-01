const kDefaultMonitorPort = 5000;

/// Builds the WebSocket URL for the endpoint monitor service.
String normalizeMonitorWsUrl(String host) {
  final t = host.trim();
  if (t.startsWith('ws://') || t.startsWith('wss://')) {
    final uri = Uri.parse(t);
    final normalizedUri =
        uri.hasPort ? uri : uri.replace(port: kDefaultMonitorPort);
    final normalized = normalizedUri.toString();
    return normalized.endsWith('/ws')
        ? normalized
        : (normalized.endsWith('/') ? '${normalized}ws' : '$normalized/ws');
  }
  final withPort = _appendDefaultPortIfMissing(t);
  return 'ws://$withPort/ws';
}

String _appendDefaultPortIfMissing(String host) {
  final trimmed = host.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('[') && trimmed.contains(']:')) return trimmed;
  if (trimmed.contains('/') ||
      trimmed.contains('?') ||
      trimmed.contains('#')) {
    final uri = Uri.parse(trimmed.startsWith('http://') ||
            trimmed.startsWith('https://')
        ? trimmed
        : 'http://$trimmed');
    if (uri.hasPort) return trimmed;
    final replaced = uri.replace(port: kDefaultMonitorPort).toString();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? replaced
        : replaced.replaceFirst(RegExp(r'^http://'), '');
  }
  if (trimmed.contains(':') && !trimmed.contains('.')) return trimmed;
  final lastColon = trimmed.lastIndexOf(':');
  if (lastColon > -1) {
    final suffix = trimmed.substring(lastColon + 1);
    if (int.tryParse(suffix) != null) return trimmed;
  }
  return '$trimmed:$kDefaultMonitorPort';
}
