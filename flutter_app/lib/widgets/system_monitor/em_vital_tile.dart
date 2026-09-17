import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ws_models.dart';
import '../../theme/em_design_system.dart';
import '../../utils/em_vital_band.dart';
import '../../utils/throughput_format.dart';
import 'em_vital_sparkline.dart';

enum VitalTileKind { cpu, ram, disk, network }

/// Single vital gauge tile with sparkline or disk bars.
class EmVitalTile extends StatefulWidget {
  const EmVitalTile({
    super.key,
    required this.kind,
    required this.info,
    required this.cpuHistory,
    required this.ramHistory,
    required this.sentHistory,
    required this.recvHistory,
    this.onTap,
  });

  final VitalTileKind kind;
  final SystemInfo info;
  final List<double> cpuHistory;
  final List<double> ramHistory;
  final List<double> sentHistory;
  final List<double> recvHistory;
  final VoidCallback? onTap;

  @override
  State<EmVitalTile> createState() => _EmVitalTileState();
}

class _EmVitalTileState extends State<EmVitalTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (title, value, percent, band) = _tileData(widget.info);

    if (band == EmVitalBand.critical && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (band != EmVitalBand.critical) {
      _pulseController.stop();
      _pulseController.value = 1;
    }

    final accent = emVitalBandColor(scheme, band);
    final glowAlpha = band == EmVitalBand.critical
        ? 0.88 + _pulseController.value * 0.12
        : 1.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(EmDesign.radiusLg),
            child: Container(
              decoration: EmDesign.cardShell(scheme).copyWith(
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08 * glowAlpha),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: glowAlpha),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(EmDesign.radiusLg),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(EmDesign.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: EmDesign.labelCaps(context, scheme)),
                          const SizedBox(height: 6),
                          Text(
                            value,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _tileChart(widget.kind, accent, percent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  (String, String, double, EmVitalBand) _tileData(SystemInfo info) {
    switch (widget.kind) {
      case VitalTileKind.cpu:
        final p = info.cpuPercent;
        return ('CPU', '${p.toStringAsFixed(1)}%', p, emVitalBandForPercent(p));
      case VitalTileKind.ram:
        final p = emRamPercent(info.ramUsedGb, info.ramTotalGb);
        return (
          'RAM',
          '${info.ramUsedGb.toStringAsFixed(1)} / ${info.ramTotalGb.toStringAsFixed(1)} GiB',
          p,
          emVitalBandForPercent(p),
        );
      case VitalTileKind.disk:
        final p = emDiskPercent(info.diskUsedGb, info.diskTotalGb);
        return (
          'DISK',
          '${info.diskUsedGb.toStringAsFixed(0)} / ${info.diskTotalGb.toStringAsFixed(0)} GiB',
          p,
          emVitalBandForPercent(p),
        );
      case VitalTileKind.network:
        final up = formatMbpsFromBytesPerSec(info.networkBytesSentPerSec);
        final down = formatMbpsFromBytesPerSec(info.networkBytesReceivedPerSec);
        final maxMbps = [
          info.networkBytesSentPerSec * 8 / 1e6,
          info.networkBytesReceivedPerSec * 8 / 1e6,
        ].reduce((a, b) => a > b ? a : b);
        final band = emNetworkThroughputBand(maxMbps);
        return ('NETWORK', '↑$up ↓$down Mbps', maxMbps, band);
    }
  }

  Widget _tileChart(VitalTileKind kind, Color accent, double percent) {
    switch (kind) {
      case VitalTileKind.cpu:
        return EmVitalSparkline(values: widget.cpuHistory, color: accent);
      case VitalTileKind.ram:
        return EmVitalSparkline(values: widget.ramHistory, color: accent);
      case VitalTileKind.network:
        return SizedBox(
          height: 36,
          child: Stack(
            children: [
              EmVitalSparkline(
                values: widget.recvHistory,
                color: accent.withValues(alpha: 0.45),
                showFill: false,
              ),
              EmVitalSparkline(
                values: widget.sentHistory,
                color: accent,
              ),
            ],
          ),
        );
      case VitalTileKind.disk:
        return _DiskVolumeBars(info: widget.info, accent: accent);
    }
  }
}

class _DiskVolumeBars extends StatelessWidget {
  const _DiskVolumeBars({required this.info, required this.accent});

  final SystemInfo info;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disks = info.disks.isNotEmpty
        ? info.disks
        : [
            DiskVolumeInfo(
              name: 'C:',
              label: '',
              usedGb: info.diskUsedGb,
              totalGb: info.diskTotalGb,
            ),
          ];

    return Column(
      children: disks.take(3).map((d) {
        final pct = emDiskPercent(d.usedGb, d.totalGb);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  d.name.replaceAll('\\', ''),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 4,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
