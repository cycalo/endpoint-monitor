/// How the phone reaches the monitored PC.
enum ConnectPath {
  wifi,
  tailscale,
}

/// SharedPreferences key for last chosen [ConnectPath].
const kConnectPathPrefKey = 'em_connect_path';

/// Parses a stored preference value into [ConnectPath].
ConnectPath? connectPathFromPref(String? value) {
  switch (value) {
    case 'wifi':
      return ConnectPath.wifi;
    case 'tailscale':
      return ConnectPath.tailscale;
    default:
      return null;
  }
}

/// Serializes [ConnectPath] for SharedPreferences.
String connectPathToPref(ConnectPath path) => switch (path) {
      ConnectPath.wifi => 'wifi',
      ConnectPath.tailscale => 'tailscale',
    };

/// Infers Tailscale vs Wi-Fi from a saved host string.
ConnectPath inferConnectPathFromHost(String host) {
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return ConnectPath.wifi;

  var hostPart = h;
  if (hostPart.startsWith('http://')) {
    hostPart = hostPart.substring(7);
  } else if (hostPart.startsWith('https://')) {
    hostPart = hostPart.substring(8);
  } else if (hostPart.startsWith('ws://')) {
    hostPart = hostPart.substring(5);
  } else if (hostPart.startsWith('wss://')) {
    hostPart = hostPart.substring(6);
  }
  hostPart = hostPart.split('/').first.split(':').first;

  if (hostPart.endsWith('.ts.net')) return ConnectPath.tailscale;
  if (hostPart.startsWith('100.')) return ConnectPath.tailscale;
  return ConnectPath.wifi;
}
