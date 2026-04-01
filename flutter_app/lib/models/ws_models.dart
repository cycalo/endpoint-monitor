import 'dart:convert';

class ProcessInfo {
  ProcessInfo({
    required this.pid,
    required this.name,
    required this.commandLine,
    required this.parentPid,
    required this.cpuPercent,
    required this.memoryMb,
    required this.startTime,
    required this.status,
  });

  final int pid;
  final String name;
  final String commandLine;
  final int parentPid;
  final double cpuPercent;
  final double memoryMb;
  final String startTime;
  final String status;

  factory ProcessInfo.fromJson(Map<String, dynamic> j) => ProcessInfo(
        pid: (j['pid'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        commandLine: j['commandLine'] as String? ?? '',
        parentPid: (j['parentPid'] as num?)?.toInt() ?? 0,
        cpuPercent: (j['cpuPercent'] as num?)?.toDouble() ?? 0,
        memoryMb: (j['memoryMb'] as num?)?.toDouble() ?? 0,
        startTime: j['startTime'] as String? ?? '',
        status: j['status'] as String? ?? '',
      );
}

class NetworkConnection {
  NetworkConnection({
    required this.pid,
    required this.processName,
    required this.localAddress,
    required this.localPort,
    required this.remoteAddress,
    required this.remotePort,
    required this.protocol,
    required this.state,
    this.durationSeconds = 0,
    this.countryCode = '',
    this.countryName = '',
    this.city = '',
    this.org = '',
  });

  final int pid;
  final String processName;
  final String localAddress;
  final int localPort;
  final String remoteAddress;
  final int remotePort;
  final String protocol;
  final String state;
  final int durationSeconds;

  /// ISO 3166-1 alpha-2 from GeoLite2 (empty if unknown / private IP).
  final String countryCode;
  final String countryName;
  final String city;
  final String org;

  factory NetworkConnection.fromJson(Map<String, dynamic> j) => NetworkConnection(
        pid: (j['pid'] as num?)?.toInt() ?? 0,
        processName: j['processName'] as String? ?? '',
        localAddress: j['localAddress'] as String? ?? '',
        localPort: (j['localPort'] as num?)?.toInt() ?? 0,
        remoteAddress: j['remoteAddress'] as String? ?? '',
        remotePort: (j['remotePort'] as num?)?.toInt() ?? 0,
        protocol: j['protocol'] as String? ?? '',
        state: j['state'] as String? ?? '',
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
        countryCode: j['countryCode'] as String? ?? '',
        countryName: j['countryName'] as String? ?? '',
        city: j['city'] as String? ?? '',
        org: j['org'] as String? ?? '',
      );

  /// Synthetic row when the IP is blocked but no live socket appears in the snapshot.
  /// [meta] is captured when the user tapped Block (process name, PID, ports).
  factory NetworkConnection.firewallBlockedPlaceholder(
    String normalizedRemoteIp,
    BlockedRemoteMeta meta,
  ) {
    final name = meta.processName.trim().isNotEmpty
        ? meta.processName.trim()
        : 'Unknown process';
    return NetworkConnection(
      pid: meta.pid,
      processName: name,
      localAddress: meta.localAddress,
      localPort: meta.localPort,
      remoteAddress: normalizedRemoteIp,
      remotePort: meta.remotePort,
      protocol: meta.protocol,
      state: 'BLOCKED',
      durationSeconds: 0,
      countryCode: '',
      countryName: '',
      city: '',
      org: '',
    );
  }
}

/// Last-known connection fields when the user blocked a remote IP (socket may disappear).
class BlockedRemoteMeta {
  const BlockedRemoteMeta({
    this.processName = '',
    this.pid = 0,
    this.remotePort = 0,
    this.protocol = '',
    this.localAddress = '',
    this.localPort = 0,
  });

  final String processName;
  final int pid;
  final int remotePort;
  final String protocol;
  final String localAddress;
  final int localPort;

  factory BlockedRemoteMeta.fromConnection(NetworkConnection n) => BlockedRemoteMeta(
        processName: n.processName,
        pid: n.pid,
        remotePort: n.remotePort,
        protocol: n.protocol,
        localAddress: n.localAddress,
        localPort: n.localPort,
      );

  Map<String, dynamic> toJson() => {
        'processName': processName,
        'pid': pid,
        'remotePort': remotePort,
        'protocol': protocol,
        'localAddress': localAddress,
        'localPort': localPort,
      };

  factory BlockedRemoteMeta.fromJson(Map<String, dynamic> j) => BlockedRemoteMeta(
        processName: j['processName'] as String? ?? '',
        pid: (j['pid'] as num?)?.toInt() ?? 0,
        remotePort: (j['remotePort'] as num?)?.toInt() ?? 0,
        protocol: j['protocol'] as String? ?? '',
        localAddress: j['localAddress'] as String? ?? '',
        localPort: (j['localPort'] as num?)?.toInt() ?? 0,
      );
}

class SysmonEvent {
  SysmonEvent({
    required this.eventId,
    required this.timestamp,
    required this.type,
    required this.pid,
    required this.processName,
    this.commandLine,
    this.parentPid,
    this.remoteAddress,
    this.remotePort,
    this.dnsQuery,
    required this.rawXml,
  });

  final int eventId;
  final String timestamp;
  final String type;
  final int pid;
  final String processName;
  final String? commandLine;
  final int? parentPid;
  final String? remoteAddress;
  final int? remotePort;
  final String? dnsQuery;
  final String rawXml;

  factory SysmonEvent.fromJson(Map<String, dynamic> j) => SysmonEvent(
        eventId: (j['eventId'] as num?)?.toInt() ?? 0,
        timestamp: j['timestamp'] as String? ?? '',
        type: j['type'] as String? ?? '',
        pid: (j['pid'] as num?)?.toInt() ?? 0,
        processName: j['processName'] as String? ?? '',
        commandLine: j['commandLine'] as String?,
        parentPid: (j['parentPid'] as num?)?.toInt(),
        remoteAddress: j['remoteAddress'] as String?,
        remotePort: (j['remotePort'] as num?)?.toInt(),
        dnsQuery: j['dnsQuery'] as String?,
        rawXml: j['rawXml'] as String? ?? '',
      );
}

/// One local fixed disk from the agent (e.g. C:\) with usage in GiB.
class DiskVolumeInfo {
  const DiskVolumeInfo({
    required this.name,
    required this.label,
    required this.usedGb,
    required this.totalGb,
  });

  final String name;
  final String label;
  final double usedGb;
  final double totalGb;

  factory DiskVolumeInfo.fromJson(Map<String, dynamic> j) => DiskVolumeInfo(
        name: j['name'] as String? ?? '',
        label: j['label'] as String? ?? '',
        usedGb: (j['usedGb'] as num?)?.toDouble() ?? 0,
        totalGb: (j['totalGb'] as num?)?.toDouble() ?? 0,
      );
}

class SystemInfo {
  SystemInfo({
    required this.systemName,
    required this.cpuPercent,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.diskUsedGb,
    required this.diskTotalGb,
    this.disks = const [],
    required this.uptime,
    required this.osCaption,
    required this.osVersion,
    required this.osArchitecture,
    required this.patchLevel,
    required this.domain,
    required this.lastBootTime,
    required this.loggedInUsers,
    required this.processCount,
    required this.networkConnectionCount,
    required this.eventsTodayCount,
    this.primaryNetworkDescription = '',
    this.primaryNetworkIpv4 = '',
    this.agentVersion = '',
    this.sysmonStatus = '',
    this.networkBytesSentPerSec = 0,
    this.networkBytesReceivedPerSec = 0,
  });

  /// Windows computer / device name (from agent).
  final String systemName;
  final double cpuPercent;
  final double ramUsedGb;
  final double ramTotalGb;
  final double diskUsedGb;
  final double diskTotalGb;

  /// Per-volume breakdown when the agent provides it (else empty).
  final List<DiskVolumeInfo> disks;

  final String uptime;

  /// Friendly OS title when provided (e.g. Microsoft Windows 11 Pro).
  final String osCaption;
  final String osVersion;
  final String osArchitecture;
  final String patchLevel;

  /// AD domain or workgroup name.
  final String domain;

  /// Last boot local time string from agent (yyyy-MM-dd HH:mm:ss).
  final String lastBootTime;
  final List<String> loggedInUsers;
  final int processCount;
  final int networkConnectionCount;
  final int eventsTodayCount;

  /// First IPv4-enabled adapter label from the agent (WMI).
  final String primaryNetworkDescription;

  /// Local IPv4 on that adapter.
  final String primaryNetworkIpv4;

  /// Windows service / assembly version string.
  final String agentVersion;

  /// Sysmon driver state: Running | Stopped | Not installed.
  final String sysmonStatus;

  /// Machine-wide bytes sent per second (sum of interfaces; from agent perf counters).
  final double networkBytesSentPerSec;

  /// Machine-wide bytes received per second (sum of interfaces).
  final double networkBytesReceivedPerSec;

  /// Display string for OS row: caption when present, else version.
  String get osDisplayLine {
    final c = osCaption.trim();
    if (c.isNotEmpty) return c;
    return osVersion;
  }

  factory SystemInfo.fromJson(Map<String, dynamic> j) => SystemInfo(
        systemName: j['systemName'] as String? ?? '',
        cpuPercent: (j['cpuPercent'] as num?)?.toDouble() ?? 0,
        ramUsedGb: (j['ramUsedGb'] as num?)?.toDouble() ?? 0,
        ramTotalGb: (j['ramTotalGb'] as num?)?.toDouble() ?? 0,
        diskUsedGb: (j['diskUsedGb'] as num?)?.toDouble() ?? 0,
        diskTotalGb: (j['diskTotalGb'] as num?)?.toDouble() ?? 0,
        disks: (j['disks'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((e) => DiskVolumeInfo.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        uptime: j['uptime'] as String? ?? '',
        osCaption: j['osCaption'] as String? ?? '',
        osVersion: j['osVersion'] as String? ?? '',
        osArchitecture: j['osArchitecture'] as String? ?? '',
        patchLevel: j['patchLevel'] as String? ?? '',
        domain: j['domain'] as String? ?? '',
        lastBootTime: j['lastBootTime'] as String? ?? '',
        loggedInUsers: (j['loggedInUsers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        processCount: (j['processCount'] as num?)?.toInt() ?? 0,
        networkConnectionCount: (j['networkConnectionCount'] as num?)?.toInt() ?? 0,
        eventsTodayCount: (j['eventsTodayCount'] as num?)?.toInt() ?? 0,
        primaryNetworkDescription: j['primaryNetworkDescription'] as String? ?? '',
        primaryNetworkIpv4: j['primaryNetworkIpv4'] as String? ?? '',
        agentVersion: j['agentVersion'] as String? ?? '',
        sysmonStatus: j['sysmonStatus'] as String? ?? '',
        networkBytesSentPerSec: (j['networkBytesSentPerSec'] as num?)?.toDouble() ?? 0,
        networkBytesReceivedPerSec: (j['networkBytesReceivedPerSec'] as num?)?.toDouble() ?? 0,
      );
}

class Alert {
  Alert({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.type,
    required this.message,
    this.relatedPid,
  });

  final String id;
  final String timestamp;
  final String severity;
  final String type;
  final String message;
  final int? relatedPid;

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
        id: j['id'] as String? ?? '',
        timestamp: j['timestamp'] as String? ?? '',
        severity: j['severity'] as String? ?? '',
        type: j['type'] as String? ?? '',
        message: j['message'] as String? ?? '',
        relatedPid: (j['relatedPid'] as num?)?.toInt(),
      );
}

class BrowserHistoryEntry {
  BrowserHistoryEntry({
    required this.browser,
    required this.url,
    required this.title,
    required this.visitTime,
    required this.visitCount,
  });

  final String browser;
  final String url;
  final String title;
  final String visitTime;
  final int visitCount;

  factory BrowserHistoryEntry.fromJson(Map<String, dynamic> j) => BrowserHistoryEntry(
        browser: j['browser'] as String? ?? '',
        url: j['url'] as String? ?? '',
        title: j['title'] as String? ?? '',
        visitTime: j['visitTime'] as String? ?? '',
        visitCount: (j['visitCount'] as num?)?.toInt() ?? 0,
      );
}

class InstalledSoftwareItem {
  InstalledSoftwareItem({
    required this.name,
    required this.version,
    required this.installDate,
    required this.vendor,
    this.installLocation = '',
    this.uninstallRegistrySubKey = '',
    this.installSizeKb = 0,
    this.canUninstall = false,
  });

  final String name;
  final String version;
  final String installDate;
  final String vendor;

  /// Install folder from registry, when present.
  final String installLocation;

  /// Registry subkey under Uninstall (used to trigger uninstall on the agent).
  final String uninstallRegistrySubKey;

  /// Estimated install size from registry (KB), 0 if unknown.
  final int installSizeKb;

  /// Agent reports whether uninstall is allowed (registry has uninstall command, NoRemove not set).
  final bool canUninstall;

  factory InstalledSoftwareItem.fromJson(Map<String, dynamic> j) => InstalledSoftwareItem(
        name: j['name'] as String? ?? '',
        version: j['version'] as String? ?? '',
        installDate: j['installDate'] as String? ?? '',
        vendor: j['vendor'] as String? ?? '',
        installLocation: j['installLocation'] as String? ?? '',
        uninstallRegistrySubKey: j['uninstallRegistrySubKey'] as String? ?? '',
        installSizeKb: (j['installSizeKb'] as num?)?.toInt() ?? 0,
        canUninstall: j['canUninstall'] as bool? ?? false,
      );
}

Map<String, dynamic> parseJsonObject(String raw) {
  final d = jsonDecode(raw);
  return Map<String, dynamic>.from(d as Map);
}
