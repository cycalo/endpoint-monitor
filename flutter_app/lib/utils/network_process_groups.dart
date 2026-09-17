import '../models/ws_models.dart';
import 'ip_normalize.dart';
import 'network_endpoint_display.dart';
import 'network_tcp_state.dart';

/// One remote peer collapsed across local ports / duplicate sockets.
class NetworkRemoteRollup {
  const NetworkRemoteRollup({
    required this.protocol,
    required this.remoteAddress,
    required this.remotePort,
    required this.sockets,
  });

  final String protocol;
  final String remoteAddress;
  final int remotePort;
  final List<NetworkConnection> sockets;

  int get socketCount => sockets.length;

  /// Prefer an established socket for detail navigation.
  NetworkConnection get representative {
    for (final s in sockets) {
      if (isEstablishedTcpState(s.state)) return s;
    }
    return sockets.first;
  }

  String get rollupKey =>
      '${protocol.toUpperCase()}|${normalizeIpForBlockList(remoteAddress)}|$remotePort';

  NetworkConnection? get geoSample {
    for (final s in sockets) {
      if (s.countryCode.isNotEmpty ||
          s.city.isNotEmpty ||
          s.countryName.isNotEmpty) {
        return s;
      }
    }
    return sockets.isNotEmpty ? sockets.first : null;
  }
}

/// Connections grouped by executable name (case-insensitive key).
class NetworkProcessGroup {
  const NetworkProcessGroup({
    required this.processName,
    required this.pids,
    required this.remotes,
    required this.localBinds,
    required this.establishedCount,
    required this.allConnections,
  });

  final String processName;
  final Set<int> pids;
  final List<NetworkRemoteRollup> remotes;
  final List<NetworkConnection> localBinds;
  final int establishedCount;
  final List<NetworkConnection> allConnections;

  String get groupKey => processName.toLowerCase();

  int get remoteCount => remotes.length;

  int get pidCount => pids.length;

  String get summaryLine {
    final parts = <String>[];
    if (establishedCount > 0) {
      parts.add('$establishedCount established');
    }
    if (remoteCount > 0) {
      parts.add('$remoteCount remote${remoteCount == 1 ? '' : 's'}');
    }
    if (parts.isEmpty && localBinds.isNotEmpty) {
      parts.add('${localBinds.length} local bind${localBinds.length == 1 ? '' : 's'}');
    }
    if (parts.isEmpty) {
      return 'No active connections';
    }
    return parts.join(' · ');
  }

  factory NetworkProcessGroup.firewallHeld({
    required String processName,
    Set<int> pids = const {},
  }) {
    return NetworkProcessGroup(
      processName: processName,
      pids: pids,
      remotes: const [],
      localBinds: const [],
      establishedCount: 0,
      allConnections: const [],
    );
  }
}

bool isLocalBindConnection(NetworkConnection n) {
  if (isListeningStyleSocket(n)) return true;
  if (isBoundTcpState(n.state)) return true;
  return false;
}

bool isTalkingConnection(NetworkConnection n) {
  if (!hasBlockableRemoteEndpoint(n.remoteAddress)) return false;
  if (n.protocol.toUpperCase() == 'TCP') {
    return isEstablishedTcpState(n.state);
  }
  // UDP with a concrete remote (unusual in our collector) counts as talking.
  return n.protocol.toUpperCase() == 'UDP' && n.remotePort > 0;
}

List<NetworkProcessGroup> buildNetworkProcessGroups(
  List<NetworkConnection> connections,
) {
  final buckets = <String, List<NetworkConnection>>{};
  final displayNames = <String, String>{};

  for (final n in connections) {
    final raw = n.processName.trim();
    final display = raw.isEmpty ? 'Unattributed' : raw;
    final key = display.toLowerCase();
    displayNames.putIfAbsent(key, () => display);
    buckets.putIfAbsent(key, () => []).add(n);
  }

  final groups = <NetworkProcessGroup>[];
  for (final entry in buckets.entries) {
    final name = displayNames[entry.key] ?? entry.key;
    final conns = entry.value;
    final pids = <int>{};
    var established = 0;
    final remoteMap = <String, List<NetworkConnection>>{};
    final binds = <NetworkConnection>[];

    for (final n in conns) {
      if (n.pid > 0) pids.add(n.pid);
      if (isTalkingConnection(n)) {
        established++;
        final rk =
            '${n.protocol.toUpperCase()}|${normalizeIpForBlockList(n.remoteAddress)}|${n.remotePort}';
        remoteMap.putIfAbsent(rk, () => []).add(n);
      } else if (isLocalBindConnection(n)) {
        binds.add(n);
      } else if (hasBlockableRemoteEndpoint(n.remoteAddress)) {
        // Non-established TCP with a remote (SYN_SENT, etc.) — roll up as remote.
        final rk =
            '${n.protocol.toUpperCase()}|${normalizeIpForBlockList(n.remoteAddress)}|${n.remotePort}';
        remoteMap.putIfAbsent(rk, () => []).add(n);
      }
    }

    final remotes = remoteMap.entries
        .map(
          (e) => NetworkRemoteRollup(
            protocol: e.value.first.protocol,
            remoteAddress: e.value.first.remoteAddress,
            remotePort: e.value.first.remotePort,
            sockets: e.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.remoteAddress.compareTo(b.remoteAddress));

    groups.add(
      NetworkProcessGroup(
        processName: name,
        pids: pids,
        remotes: remotes,
        localBinds: binds,
        establishedCount: established,
        allConnections: conns,
      ),
    );
  }

  groups.sort((a, b) {
    if (a.establishedCount != b.establishedCount) {
      return b.establishedCount.compareTo(a.establishedCount);
    }
    return a.processName.toLowerCase().compareTo(b.processName.toLowerCase());
  });

  return groups;
}

bool networkGroupMatchesSearch(NetworkProcessGroup group, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (group.processName.toLowerCase().contains(q)) return true;
  for (final pid in group.pids) {
    if ('$pid'.contains(q)) return true;
  }
  for (final c in group.allConnections) {
    if (c.remoteAddress.toLowerCase().contains(q) ||
        c.localAddress.toLowerCase().contains(q) ||
        '${c.localPort}'.contains(q) ||
        '${c.remotePort}'.contains(q) ||
        c.city.toLowerCase().contains(q) ||
        c.countryName.toLowerCase().contains(q) ||
        c.countryCode.toLowerCase().contains(q) ||
        c.org.toLowerCase().contains(q)) {
      return true;
    }
  }
  return false;
}

/// Default Apps view: show groups with at least one established talking socket.
bool networkGroupIsTalkingByDefault(NetworkProcessGroup group) =>
    group.establishedCount > 0;

/// Default Apps view also keeps firewall-blocked apps after their sockets drop.
bool networkGroupVisibleInDefaultAppsView(
  NetworkProcessGroup group,
  Iterable<String> blockedProcessNames,
) {
  if (networkGroupIsTalkingByDefault(group)) return true;
  return processNameHasFirewallBlock(group.processName, blockedProcessNames);
}

Set<int> _runningPidsForProcess(
  String processName,
  Map<String, Set<int>> runningPidsByProcessName,
) {
  if (runningPidsByProcessName.isEmpty) return const {};
  final target = processName.trim().toLowerCase();
  if (target.isEmpty) return const {};
  final out = <int>{};
  void addAll(String key) {
    final pids = runningPidsByProcessName[key];
    if (pids != null) out.addAll(pids);
  }

  addAll(target);
  if (target.endsWith('.exe')) {
    addAll(target.substring(0, target.length - 4));
  } else {
    addAll('$target.exe');
  }
  return out;
}

/// Re-inserts process firewall rules that vanished from the live socket dump.
List<NetworkProcessGroup> mergeFirewallBlockedProcessGroups({
  required List<NetworkProcessGroup> groups,
  required Iterable<FirewallProcessBlockInfo> blocks,
  Map<String, Set<int>> runningPidsByProcessName = const {},
}) {
  final out = List<NetworkProcessGroup>.from(groups);
  for (final block in blocks) {
    final name = block.processName.trim();
    if (name.isEmpty) continue;
    if (out.any((g) => processNameHasFirewallBlock(g.processName, [name]))) {
      continue;
    }
    out.add(
      NetworkProcessGroup.firewallHeld(
        processName: name,
        pids: _runningPidsForProcess(name, runningPidsByProcessName),
      ),
    );
  }
  out.sort((a, b) {
    final names = blocks.map((e) => e.processName);
    final aSilentBlocked = a.establishedCount == 0 &&
        processNameHasFirewallBlock(a.processName, names);
    final bSilentBlocked = b.establishedCount == 0 &&
        processNameHasFirewallBlock(b.processName, names);
    if (aSilentBlocked != bSilentBlocked) {
      return aSilentBlocked ? -1 : 1;
    }
    if (a.establishedCount != b.establishedCount) {
      return b.establishedCount.compareTo(a.establishedCount);
    }
    return a.processName.toLowerCase().compareTo(b.processName.toLowerCase());
  });
  return out;
}

bool processNameHasFirewallBlock(
  String processName,
  Iterable<String> blockedProcessNames,
) {
  final target = processName.trim().toLowerCase();
  var normalized = target;
  if (normalized.isNotEmpty && !normalized.endsWith('.exe')) {
    normalized = '$normalized.exe';
  }
  for (final raw in blockedProcessNames) {
    final n = raw.trim().toLowerCase();
    if (n == target || n == normalized) return true;
  }
  return false;
}

FirewallProcessBlockInfo? processFirewallBlockForName(
  String processName,
  Iterable<FirewallProcessBlockInfo> blocks,
) {
  final target = processName.trim().toLowerCase();
  var normalized = target;
  if (normalized.isNotEmpty && !normalized.endsWith('.exe')) {
    normalized = '$normalized.exe';
  }
  for (final b in blocks) {
    final n = b.processName.trim().toLowerCase();
    if (n == target || n == normalized) return b;
  }
  return null;
}

/// Lightweight process-block snapshot for grouping (no Flutter dependency).
class FirewallProcessBlockInfo {
  const FirewallProcessBlockInfo({
    required this.processName,
    required this.direction,
  });

  final String processName;
  final String direction;
}
