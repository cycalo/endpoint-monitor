/// Display helpers for local/remote addresses on the Network screens.
library;

import '../models/ws_models.dart';

/// Listening sockets and “no remote peer” rows — there is no specific remote IP to block.
bool isListeningStyleSocket(NetworkConnection n) {
  final r = n.remoteAddress.trim();
  if (r.isEmpty || r == '*' || r == '::' || r == '0.0.0.0') return true;
  if (n.remotePort == 0) return true;
  final st = n.state.trim();
  final mib = int.tryParse(st);
  if (mib == 2) return true;
  if (mib == null && st.toUpperCase() == 'LISTEN') return true;
  return false;
}

/// True if [raw] looks like an IPv6 address (contains `:`).
bool isIpv6Address(String raw) {
  final a = raw.trim();
  if (a.isEmpty) return false;
  return a.contains(':');
}

/// Formats [address] and [port] for UI. IPv4 uses `addr:port` (e.g. `0.0.0.0`,
/// `192.0.2.1:443`). IPv6 uses a space before the port so colons in the address
/// stay unambiguous. Special case: IPv6 loopback `::1` → `localhost`.
String formatNetworkEndpoint(String address, int port) {
  final a = address.trim();
  if (a.isEmpty) {
    return '—';
  }
  if (a == '::1') {
    return port > 0 ? 'localhost:$port' : 'localhost';
  }
  if (isIpv6Address(a)) {
    return port > 0 ? '$a $port' : a;
  }
  return port > 0 ? '$a:$port' : a;
}

/// Whether blocking outbound to this remote makes sense (has a concrete peer).
bool hasBlockableRemoteEndpoint(String address) {
  final a = address.trim();
  if (a.isEmpty) return false;
  if (a == '*' || a == '::' || a == '0.0.0.0') return false;
  return true;
}
