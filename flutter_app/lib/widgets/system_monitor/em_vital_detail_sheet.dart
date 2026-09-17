import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ws_models.dart';
import '../../theme/em_design_system.dart';
import '../../utils/em_vital_band.dart';
import '../../utils/throughput_format.dart';
import 'em_vital_sparkline.dart';
import 'em_vital_tile.dart';

Future<void> showVitalDetailSheet({
  required BuildContext context,
  required VitalTileKind kind,
  required SystemInfo info,
  required List<double> cpuHistory,
  required List<double> ramHistory,
  required List<double> sentHistory,
  required List<double> recvHistory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                _sheetTitle(kind),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              ..._sheetBody(
                context: ctx,
                kind: kind,
                info: info,
                cpuHistory: cpuHistory,
                ramHistory: ramHistory,
                sentHistory: sentHistory,
                recvHistory: recvHistory,
                scheme: scheme,
              ),
            ],
          );
        },
      );
    },
  );
}

String _sheetTitle(VitalTileKind kind) {
  switch (kind) {
    case VitalTileKind.cpu:
      return 'CPU detail';
    case VitalTileKind.ram:
      return 'Memory detail';
    case VitalTileKind.disk:
      return 'Disk detail';
    case VitalTileKind.network:
      return 'Network detail';
  }
}

List<Widget> _sheetBody({
  required BuildContext context,
  required VitalTileKind kind,
  required SystemInfo info,
  required List<double> cpuHistory,
  required List<double> ramHistory,
  required List<double> sentHistory,
  required List<double> recvHistory,
  required ColorScheme scheme,
}) {
  final mono = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    color: scheme.onSurfaceVariant,
  );

  switch (kind) {
    case VitalTileKind.cpu:
      final band = emVitalBandForPercent(info.cpuPercent);
      final accent = emVitalBandColor(scheme, band);
      return [
        Text(
          '${info.cpuPercent.toStringAsFixed(1)}%',
          style: GoogleFonts.manrope(
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        EmVitalSparkline(values: cpuHistory, color: accent, height: 80),
        const SizedBox(height: 16),
        _row('Processes', '${info.processCount}', mono),
      ];
    case VitalTileKind.ram:
      final pct = emRamPercent(info.ramUsedGb, info.ramTotalGb);
      final band = emVitalBandForPercent(pct);
      final accent = emVitalBandColor(scheme, band);
      return [
        Text(
          '${info.ramUsedGb.toStringAsFixed(1)} / ${info.ramTotalGb.toStringAsFixed(1)} GiB',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text('${pct.toStringAsFixed(1)}% utilized', style: mono),
        const SizedBox(height: 12),
        EmVitalSparkline(values: ramHistory, color: accent, height: 80),
      ];
    case VitalTileKind.disk:
      final disks = info.disks.isNotEmpty
          ? info.disks
          : [
              DiskVolumeInfo(
                name: 'Total',
                label: '',
                usedGb: info.diskUsedGb,
                totalGb: info.diskTotalGb,
              ),
            ];
      return [
        Text(
          '${info.diskUsedGb.toStringAsFixed(0)} / ${info.diskTotalGb.toStringAsFixed(0)} GiB total',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ...disks.map((d) {
          final pct = emDiskPercent(d.usedGb, d.totalGb);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: EmDesign.cardShell(
                scheme,
                color: scheme.surfaceContainerLow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.label.isNotEmpty ? '${d.name} ${d.label}' : d.name,
                    style: EmDesign.labelCaps(context, scheme),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.usedGb.toStringAsFixed(1)} / ${d.totalGb.toStringAsFixed(1)} GiB (${pct.toStringAsFixed(0)}%)',
                    style: mono,
                  ),
                ],
              ),
            ),
          );
        }),
      ];
    case VitalTileKind.network:
      final up = formatMbpsFromBytesPerSec(info.networkBytesSentPerSec);
      final down = formatMbpsFromBytesPerSec(info.networkBytesReceivedPerSec);
      final accent = scheme.tertiary;
      return [
        Text(
          '↑ $up Mbps  ·  ↓ $down Mbps',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: Stack(
            children: [
              EmVitalSparkline(
                values: recvHistory,
                color: accent.withValues(alpha: 0.45),
                height: 80,
                showFill: false,
              ),
              EmVitalSparkline(
                values: sentHistory,
                color: accent,
                height: 80,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _row('Connections', '${info.networkConnectionCount}', mono),
        if (info.primaryNetworkDescription.isNotEmpty)
          _row('Adapter', info.primaryNetworkDescription, mono),
        if (info.primaryNetworkIpv4.isNotEmpty)
          _row('IPv4', info.primaryNetworkIpv4, mono),
      ];
  }
}

Widget _row(String label, String value, TextStyle mono) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: mono.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(value, style: mono)),
      ],
    ),
  );
}
