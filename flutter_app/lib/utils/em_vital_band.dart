import 'package:flutter/material.dart';

import '../theme/em_design_system.dart';

/// Stepped severity band for a single vital (CPU%, RAM%, disk%, etc.).
enum EmVitalBand {
  calm,
  warn,
  critical,
}

/// Returns the band for a utilization percentage (0–100).
EmVitalBand emVitalBandForPercent(double percent) {
  if (percent >= 80) return EmVitalBand.critical;
  if (percent >= 60) return EmVitalBand.warn;
  return EmVitalBand.calm;
}

/// Token-based accent color for [band].
Color emVitalBandColor(ColorScheme scheme, EmVitalBand band) {
  switch (band) {
    case EmVitalBand.calm:
      return scheme.tertiary;
    case EmVitalBand.warn:
      return EmDesign.controlPowerWarn(scheme);
    case EmVitalBand.critical:
      return scheme.error;
  }
}

/// RAM utilization percent from GiB values.
double emRamPercent(double usedGb, double totalGb) {
  if (totalGb <= 0) return 0;
  return (usedGb / totalGb * 100).clamp(0, 100);
}

/// Disk utilization percent from GiB values.
double emDiskPercent(double usedGb, double totalGb) {
  if (totalGb <= 0) return 0;
  return (usedGb / totalGb * 100).clamp(0, 100);
}

/// Composite endpoint health score (0–100, higher is healthier).
double emEndpointHealthScore({
  required double cpuPercent,
  required double ramPercent,
  required double diskPercent,
}) {
  final raw = 100 -
      (0.40 * cpuPercent + 0.35 * ramPercent + 0.25 * diskPercent);
  return raw.clamp(0, 100);
}

/// Band for network throughput (Mbps, not a utilization percent).
EmVitalBand emNetworkThroughputBand(double maxMbps) {
  if (maxMbps >= 100) return EmVitalBand.critical;
  if (maxMbps >= 25) return EmVitalBand.warn;
  return EmVitalBand.calm;
}

/// Worst band across CPU, RAM, and disk utilization.
EmVitalBand emWorstVitalBand({
  required double cpuPercent,
  required double ramPercent,
  required double diskPercent,
}) {
  final bands = [
    emVitalBandForPercent(cpuPercent),
    emVitalBandForPercent(ramPercent),
    emVitalBandForPercent(diskPercent),
  ];
  if (bands.contains(EmVitalBand.critical)) return EmVitalBand.critical;
  if (bands.contains(EmVitalBand.warn)) return EmVitalBand.warn;
  return EmVitalBand.calm;
}

/// Parses agent uptime strings like `3d 4h 12m` into a [Duration].
Duration? emParseAgentUptime(String uptime) {
  final trimmed = uptime.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(
    r'^(\d+)d\s+(\d+)h\s+(\d+)m$',
  ).firstMatch(trimmed);
  if (match == null) return null;
  final days = int.tryParse(match.group(1)!) ?? 0;
  final hours = int.tryParse(match.group(2)!) ?? 0;
  final minutes = int.tryParse(match.group(3)!) ?? 0;
  return Duration(days: days, hours: hours, minutes: minutes);
}

/// Formats a duration as `Xd Yh Zm` (matches agent style).
String emFormatUptimeDuration(Duration d) {
  return '${d.inDays}d ${d.inHours.remainder(24)}h ${d.inMinutes.remainder(60)}m';
}
