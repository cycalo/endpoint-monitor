import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/connection_bloc.dart';
import '../bloc/alerts_bloc.dart';
import '../bloc/process_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../bloc/threat_intel_bloc.dart';
import '../bloc/activity_heatmap_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/activity_heatmap_card.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_gradient_button.dart';
import '../widgets/em_loading_states.dart';
import '../utils/em_snapshot_cache.dart';

/// Dashboard aligned with [flutter_design/dashboard_with_system_identity/code.html].
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static bool _looksLikeIpv4(String s) {
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono =
        GoogleFonts.jetBrainsMono(fontSize: 12, color: scheme.onSurfaceVariant);
    final radiusCard = EmDesign.radiusLg;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: BlocBuilder<SystemInfoBloc, SystemInfoState>(
        builder: (context, s) {
          final i = s.info;
          return BlocBuilder<ConnectionBloc, EmConnectionState>(
            builder: (context, conn) {
              final hostDisplay = emDisplayConnectionHost(conn.host);
              final ipLine = _looksLikeIpv4(hostDisplay) ? hostDisplay : '—';

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DashboardDataBootstrap(),
                    const _DashboardConnectionHero(),
                    if (!conn.isConnected) ...[
                      const SizedBox(height: 24),
                      if (i != null) ...[
                        FutureBuilder<DateTime?>(
                          future: EmSnapshotCache.systemInfoCachedAt(),
                          builder: (context, snap) {
                            return EmStaleSnapshotBanner(cachedAt: snap.data);
                          },
                        ),
                        const SizedBox(height: 16),
                        _DashboardOfflineMetrics(
                          info: i,
                          scheme: scheme,
                          theme: theme,
                          radiusCard: radiusCard,
                          mono: mono,
                          hostDisplay: hostDisplay,
                          ipLine: ipLine,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _DashboardDisconnectedMetrics(
                        scheme: scheme,
                        theme: theme,
                      ),
                    ] else ...[
                      const EmPageIntro(
                        title: 'Dashboard',
                        subtitle:
                            'Live endpoint health, activity, and system identity.',
                        padding: EdgeInsets.only(top: 8, bottom: 16),
                      ),
                      const _DashboardActivityHeatmap(),
                      const SizedBox(height: 16),
                      const _DashboardThreatIntelCard(),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: i == null
                            ? Column(
                                key: const ValueKey('metrics-loading'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  EmStatusPanel(
                                    loading: true,
                                    message: 'Syncing system metrics…',
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('metrics-loaded'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  BlocBuilder<AlertsBloc, AlertsState>(
                                    builder: (context, alerts) {
                                      final unacked = alerts.items
                                          .where((a) =>
                                              !alerts.acked.contains(a.id))
                                          .length;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _SummaryMetricsPair(
                                            processCount: i.processCount,
                                            networkCount:
                                                i.networkConnectionCount,
                                            scheme: scheme,
                                            theme: theme,
                                            radiusCard: radiusCard,
                                          ),
                                          const SizedBox(height: 24),
                                          LayoutBuilder(
                                            builder: (context, c) {
                                              final twoCol = c.maxWidth >= 480;
                                              final cpu = _CpuLoadCard(
                                                info: i,
                                                mono: mono,
                                                scheme: scheme,
                                                theme: theme,
                                                radiusCard: radiusCard,
                                              );
                                              final ramDisk = _RamDiskCard(
                                                info: i,
                                                scheme: scheme,
                                                theme: theme,
                                                radiusCard: radiusCard,
                                              );
                                              if (twoCol) {
                                                return Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(child: cpu),
                                                    const SizedBox(width: 16),
                                                    Expanded(child: ramDisk),
                                                  ],
                                                );
                                              }
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  cpu,
                                                  const SizedBox(height: 16),
                                                  ramDisk,
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 24),
                                          _SystemInformationCard(
                                            info: i,
                                            hostDisplay: hostDisplay,
                                            ipLine: ipLine,
                                            mono: mono,
                                            scheme: scheme,
                                            theme: theme,
                                            radiusCard: radiusCard,
                                          ),
                                          if (unacked > 0) ...[
                                            const SizedBox(height: 12),
                                            _AlertsStrip(
                                                count: unacked, scheme: scheme),
                                          ],
                                          const SizedBox(height: 32),
                                          _DangerZoneSection(
                                            scheme: scheme,
                                            theme: theme,
                                            radiusCard: radiusCard,
                                            onIsolate: () =>
                                                _runIsolateFlow(context),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _runIsolateFlow(BuildContext context) async {
    final proc = context.read<ProcessBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm isolation'),
        content: const Text(
          'Isolating the machine will terminate all external networking protocols except for this secure management channel. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm isolation'),
        content: const Text(
          'Are you absolutely sure? Remote desktop, file shares, and internet access may be blocked immediately.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Isolate')),
        ],
      ),
    );
    if (ok2 == true && context.mounted) {
      proc.sendCommand({'type': 'isolate_machine'});
    }
  }
}

class _DashboardConnectionHero extends StatelessWidget {
  const _DashboardConnectionHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BlocBuilder<ConnectionBloc, EmConnectionState>(
      builder: (context, c) {
        final host = emDisplayConnectionHost(c.host);
        final accentGlow = c.isConnected
            ? scheme.tertiary
            : c.status == ConnectionStatus.connecting
                ? scheme.primary
                : null;
        final iconColor = c.isConnected
            ? scheme.tertiary.withValues(alpha: 0.62)
            : c.status == ConnectionStatus.connecting
                ? scheme.primary.withValues(alpha: 0.58)
                : scheme.onSurfaceVariant.withValues(alpha: 0.45);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(EmDesign.radiusLg),
              boxShadow: EmDesign.heroElevationShadows(
                scheme,
                accentGlow: accentGlow,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(EmDesign.radiusLg),
              child: DecoratedBox(
                decoration: EmDesign.heroCardDecoration(scheme),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('STATUS',
                                style: EmDesign.labelCaps(context, scheme)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (c.isConnected) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: scheme.tertiary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.tertiary
                                              .withValues(alpha: 0.45),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Connected',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ] else if (c.status ==
                                    ConnectionStatus.connecting) ...[
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Connecting…',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'Disconnected',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      color: scheme.outline,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.isConnected
                                  ? 'Secure channel · $host'
                                  : c.status == ConnectionStatus.connecting
                                      ? 'Restoring the secure channel…'
                                      : 'Connection lost. Use Reconnect below or the link control in the header.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: c.isConnected
                                    ? scheme.tertiary
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: DecoratedBox(
                          decoration: EmDesign.heroIconWellDecoration(scheme),
                          child: Center(
                            child: Icon(
                              Icons.monitor_heart_rounded,
                              size: 36,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Read-only metrics from cache while disconnected.
class _DashboardOfflineMetrics extends StatelessWidget {
  const _DashboardOfflineMetrics({
    required this.info,
    required this.scheme,
    required this.theme,
    required this.radiusCard,
    required this.mono,
    required this.hostDisplay,
    required this.ipLine,
  });

  final SystemInfo info;
  final ColorScheme scheme;
  final ThemeData theme;
  final double radiusCard;
  final TextStyle mono;
  final String hostDisplay;
  final String ipLine;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryMetricsPair(
            processCount: info.processCount,
            networkCount: info.networkConnectionCount,
            scheme: scheme,
            theme: theme,
            radiusCard: radiusCard,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final twoCol = c.maxWidth >= 480;
              final cpu = _CpuLoadCard(
                info: info,
                mono: mono,
                scheme: scheme,
                theme: theme,
                radiusCard: radiusCard,
              );
              final ramDisk = _RamDiskCard(
                info: info,
                scheme: scheme,
                theme: theme,
                radiusCard: radiusCard,
              );
              if (twoCol) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cpu),
                    const SizedBox(width: 16),
                    Expanded(child: ramDisk),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cpu,
                  const SizedBox(height: 16),
                  ramDisk,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _SystemInformationCard(
            info: info,
            hostDisplay: hostDisplay,
            ipLine: ipLine,
            mono: mono,
            scheme: scheme,
            theme: theme,
            radiusCard: radiusCard,
          ),
        ],
      ),
    );
  }
}

class _DashboardDisconnectedMetrics extends StatelessWidget {
  const _DashboardDisconnectedMetrics({
    required this.scheme,
    required this.theme,
  });

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionBloc, EmConnectionState>(
      builder: (context, c) {
        if (c.status == ConnectionStatus.connecting) {
          return EmStatusPanel(
            loading: true,
            message: 'Reconnecting to the secure channel…',
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.message != null && c.message!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    c.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                EmStatusPanel(
                  icon: Icons.cloud_off_rounded,
                  message:
                      'Connection lost. Reconnect to resume live monitoring.',
                ),
                const SizedBox(height: 8),
              ],
              EmGradientButton(
                label: 'Reconnect',
                icon: Icons.link_rounded,
                onPressed: () {
                  context.read<ConnectionBloc>().add(
                        const ConnectionReconnectRequested(),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// SVG stroke path from [code.html] (viewBox 0 0 472 149), scaled to [size].
Path _cpuChartStrokePath(Size size) {
  const w = 472.0;
  const h = 149.0;
  Offset p(double x, double y) =>
      Offset(x / w * size.width, y / h * size.height);

  final path = Path()..moveTo(p(0, 109).dx, p(0, 109).dy);
  void c(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    path.cubicTo(
      p(x1, y1).dx,
      p(x1, y1).dy,
      p(x2, y2).dx,
      p(x2, y2).dy,
      p(x3, y3).dx,
      p(x3, y3).dy,
    );
  }

  c(18.1538, 109, 18.1538, 21, 36.3077, 21);
  c(54.4615, 21, 54.4615, 41, 72.6154, 41);
  c(90.7692, 41, 90.7692, 93, 108.923, 93);
  c(127.077, 93, 127.077, 33, 145.231, 33);
  c(163.385, 33, 163.385, 101, 181.538, 101);
  c(199.692, 101, 199.692, 61, 217.846, 61);
  c(236, 61, 236, 45, 254.154, 45);
  c(272.308, 45, 272.308, 121, 290.462, 121);
  c(308.615, 121, 308.615, 149, 326.769, 149);
  c(344.923, 149, 344.923, 1, 363.077, 1);
  c(381.231, 1, 381.231, 81, 399.385, 81);
  c(417.538, 81, 417.538, 129, 435.692, 129);
  c(453.846, 129, 453.846, 25, 472, 25);
  return path;
}

class _CpuChartPainter extends CustomPainter {
  _CpuChartPainter({required this.tertiary});

  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final stroke = _cpuChartStrokePath(size);
    final fill = Path.from(stroke)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final rect = Offset.zero & size;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          tertiary.withValues(alpha: 0.3),
          tertiary.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawPath(fill, fillPaint);

    final linePaint = Paint()
      ..color = tertiary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stroke, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CpuChartPainter oldDelegate) =>
      oldDelegate.tertiary != tertiary;
}

class _CpuLoadCard extends StatelessWidget {
  const _CpuLoadCard({
    required this.info,
    required this.mono,
    required this.scheme,
    required this.theme,
    required this.radiusCard,
  });

  final SystemInfo info;
  final TextStyle mono;
  final ColorScheme scheme;
  final ThemeData theme;
  final double radiusCard;

  @override
  Widget build(BuildContext context) {
    final cpu = info.cpuPercent.clamp(0, 100);
    final headline = theme.textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radiusCard),
        border: EmDesign.ghostBorder(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CPU LOAD',
                      style: EmDesign.labelCaps(context, scheme),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: cpu.toStringAsFixed(0),
                            style: headline.copyWith(fontSize: 34),
                          ),
                          TextSpan(
                            text: '%',
                            style: headline.copyWith(
                              fontSize: 18,
                              color: scheme.primary.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.speed_rounded, color: scheme.tertiary, size: 28),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: _CpuChartPainter(tertiary: scheme.tertiary),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Illustrative trend',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: scheme.outline.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _chartTickLeft(),
                style: mono.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: scheme.outline,
                ),
              ),
              Text(
                _chartTickMid(),
                style: mono.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: scheme.outline,
                ),
              ),
              Text(
                _chartTickRight(),
                style: mono.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _chartTickLeft() {
    final now = DateTime.now();
    final t = now.subtract(const Duration(minutes: 30));
    return _fmtClock(t);
  }

  String _chartTickMid() {
    final now = DateTime.now();
    final t = now.subtract(const Duration(minutes: 15));
    return _fmtClock(t);
  }

  String _chartTickRight() => _fmtClock(DateTime.now());

  String _fmtClock(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _RamDiskCard extends StatefulWidget {
  const _RamDiskCard({
    required this.info,
    required this.scheme,
    required this.theme,
    required this.radiusCard,
  });

  final SystemInfo info;
  final ColorScheme scheme;
  final ThemeData theme;
  final double radiusCard;

  @override
  State<_RamDiskCard> createState() => _RamDiskCardState();
}

class _RamDiskCardState extends State<_RamDiskCard> {
  bool _diskVolumesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final scheme = widget.scheme;
    final theme = widget.theme;
    final radiusCard = widget.radiusCard;

    final ramFrac = info.ramTotalGb > 0
        ? (info.ramUsedGb / info.ramTotalGb).clamp(0.0, 1.0)
        : 0.0;
    final body = theme.textTheme.bodySmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radiusCard),
        border: EmDesign.ghostBorder(scheme),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RAM Usage', style: body?.copyWith(color: scheme.onSurface)),
              Text(
                _ramLine(info),
                style: body?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ramFrac,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerLow,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          if (info.disks.isNotEmpty) ...[
            Tooltip(
              message: _diskVolumesExpanded
                  ? 'Hide per-disk breakdown'
                  : 'Show per-disk breakdown',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(
                      () => _diskVolumesExpanded = !_diskVolumesExpanded),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Total Disk Space',
                                style: body?.copyWith(color: scheme.onSurface),
                              ),
                            ),
                            Text(
                              _aggregateDiskLine(info),
                              style: body?.copyWith(color: scheme.tertiary),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _diskVolumesExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 22,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: info.diskTotalGb > 0
                                ? (info.diskUsedGb / info.diskTotalGb)
                                    .clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 8,
                            backgroundColor: scheme.surfaceContainerLow,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(scheme.tertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _diskVolumesExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 14),
                        ..._diskVolumeWidgets(
                          info,
                          scheme,
                          theme,
                          body,
                          firstVolumeTopGap: 0,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Disk Space',
                  style: body?.copyWith(color: scheme.onSurface),
                ),
                Text(
                  _aggregateDiskLine(info),
                  style: body?.copyWith(color: scheme.tertiary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: info.diskTotalGb > 0
                    ? (info.diskUsedGb / info.diskTotalGb).clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerLow,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.tertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<Widget> _diskVolumeWidgets(
    SystemInfo info,
    ColorScheme scheme,
    ThemeData theme,
    TextStyle? body, {
    double firstVolumeTopGap = 10,
  }) {
    final out = <Widget>[];
    for (var i = 0; i < info.disks.length; i++) {
      final d = info.disks[i];
      final frac = d.totalGb > 0 ? (d.usedGb / d.totalGb).clamp(0.0, 1.0) : 0.0;
      if (i > 0) {
        out.add(const SizedBox(height: 14));
      } else if (firstVolumeTopGap > 0) {
        out.add(SizedBox(height: firstVolumeTopGap));
      }
      final accent = _diskAccentForIndex(i, scheme);
      final diskSurface = Color.alphaBlend(
        accent.withValues(alpha: 0.12),
        scheme.surfaceContainerLow,
      );
      out.add(
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: diskSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _driveTitle(d.name),
                          style: body?.copyWith(color: scheme.onSurface),
                        ),
                        if (d.label.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              d.label.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _storageLine(d.usedGb, d.totalGb),
                    style: body?.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return out;
  }

  static Color _diskAccentForIndex(int index, ColorScheme scheme) {
    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.primaryFixed,
      scheme.tertiaryFixed,
    ];
    return palette[index % palette.length];
  }

  static String _driveTitle(String path) {
    final t = path.trim();
    if (t.isEmpty) return '—';
    final letter = t.replaceAll(r'\', '').replaceAll('/', '');
    if (letter.isEmpty) return t;
    return '$letter:';
  }

  static String _ramLine(SystemInfo i) {
    if (i.ramTotalGb <= 0) return '—';
    return '${i.ramUsedGb.toStringAsFixed(1)} GB / ${i.ramTotalGb.toStringAsFixed(0)} GB';
  }

  static String _aggregateDiskLine(SystemInfo i) {
    return _storageLine(i.diskUsedGb, i.diskTotalGb);
  }

  static String _storageLine(double u, double t) {
    if (t <= 0) return '—';
    if (t >= 1024) {
      return '${(u / 1024).toStringAsFixed(1)} TB / ${(t / 1024).toStringAsFixed(1)} TB';
    }
    return '${u.toStringAsFixed(1)} GB / ${t.toStringAsFixed(0)} GB';
  }
}

class _SystemInformationCard extends StatelessWidget {
  const _SystemInformationCard({
    required this.info,
    required this.hostDisplay,
    required this.ipLine,
    required this.mono,
    required this.scheme,
    required this.theme,
    required this.radiusCard,
  });

  final SystemInfo info;
  final String hostDisplay;
  final String ipLine;
  final TextStyle mono;
  final ColorScheme scheme;
  final ThemeData theme;
  final double radiusCard;

  static String _dash(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? '—' : t;
  }

  @override
  Widget build(BuildContext context) {
    final patch = info.patchLevel;
    final isLatest = patch.isNotEmpty && patch.toLowerCase().contains('latest');
    final usersLine = info.loggedInUsers.isEmpty
        ? '—'
        : '${info.loggedInUsers.take(8).join(', ')}${info.loggedInUsers.length > 8 ? '…' : ''}';
    final archDisplay = _formatArchitecture(info.osArchitecture);
    final powerOnLine = _dash(info.lastBootTime);
    final uptimeLine = info.uptime.trim().isEmpty ? '—' : info.uptime.trim();
    final networkLine = _primaryNetworkLine(info, ipLine);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radiusCard),
        border: EmDesign.ghostBorder(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                ),
                child: Icon(
                  Icons.settings_input_component_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'System information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('SYSTEM NAME', _dash(info.systemName), valueMono: true),
          _infoRow('OS VERSION', _dash(info.osDisplayLine)),
          _infoRow('ARCHITECTURE', archDisplay),
          _infoRow('POWERED ON AT', powerOnLine, valueMono: true),
          _infoRow('UPTIME', uptimeLine, valueMono: true),
          _infoRow('PATCH LEVEL', _patchValue(patch, isLatest)),
          _infoRow('PRIMARY NETWORK', networkLine),
          if (hostDisplay != '—' && ipLine == '—')
            _infoRow('MGMT ENDPOINT', hostDisplay, valueMono: true),
          _infoRow(
            'MONITORING SERVICE',
            _dash(info.agentVersion),
            valueMono: true,
          ),
          _infoRow('SYSMON', _sysmonValueWidget(info.sysmonStatus)),
          _infoRow('EVENTS TODAY', '${info.eventsTodayCount}'),
          _infoRow('INTERACTIVE USERS', usersLine),
        ],
      ),
    );
  }

  /// WMI often already includes "64-bit"; avoid appending a duplicate suffix.
  static String _formatArchitecture(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    return t;
  }

  String _primaryNetworkLine(SystemInfo info, String ipFallback) {
    final a = info.primaryNetworkDescription.trim();
    final ip = info.primaryNetworkIpv4.trim().isNotEmpty
        ? info.primaryNetworkIpv4.trim()
        : ipFallback.trim();
    final ipShow = ip.isEmpty || ip == '—' ? '' : ip;
    if (a.isEmpty && ipShow.isEmpty) return '—';
    if (a.isEmpty) return ipShow;
    if (ipShow.isEmpty) return a;
    return '$a  •  $ipShow';
  }

  Widget _sysmonValueWidget(String status) {
    final s = status.trim();
    if (s.isEmpty) {
      return Text('—', style: theme.textTheme.bodySmall);
    }
    final lower = s.toLowerCase();
    final color = lower == 'running'
        ? scheme.tertiary
        : (lower.contains('not installed') ? scheme.outline : scheme.error);
    return Text(
      s,
      textAlign: TextAlign.right,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _patchValue(String patch, bool isLatest) {
    if (patch.isEmpty) {
      return Text('—', style: theme.textTheme.bodySmall);
    }
    if (isLatest) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: scheme.tertiary),
          const SizedBox(width: 4),
          Text(
            'Latest',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.tertiary,
            ),
          ),
        ],
      );
    }
    return Text(patch, style: theme.textTheme.bodySmall);
  }

  Widget _infoRow(
    String label,
    Object value, {
    bool valueMono = false,
  }) {
    final Widget valueChild;
    if (value is Widget) {
      valueChild = value;
    } else {
      final s = value as String;
      final vStyle = valueMono
          ? mono.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            )
          : theme.textTheme.bodySmall;
      valueChild = Text(
        s,
        textAlign: TextAlign.right,
        style: vStyle,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: mono.copyWith(
              fontSize: 10,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueChild,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricsPair extends StatelessWidget {
  const _SummaryMetricsPair({
    required this.processCount,
    required this.networkCount,
    required this.scheme,
    required this.theme,
    required this.radiusCard,
  });

  final int processCount;
  final int networkCount;
  final ColorScheme scheme;
  final ThemeData theme;
  final double radiusCard;

  @override
  Widget build(BuildContext context) {
    final big = _summaryNumberStyle(theme, scheme);
    final sub = theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ) ??
        TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        );

    // Rounded rects cannot use [Border] with different colors per side (Flutter asserts).
    // Uniform ghost edge + a solid left accent strip matches the mock without breaking paint.
    // [Stack] avoids Row+stretch under unbounded height (scroll Column → Expanded → ∞).
    Widget tile(
      String value,
      String label,
      Color accent,
      VoidCallback onTap,
    ) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusCard),
          child: Ink(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(radiusCard),
              border: EmDesign.ghostBorder(scheme),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(color: accent),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(value, style: big),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                              child: Text(label.toUpperCase(), style: sub)),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: accent.withValues(alpha: 0.65),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: tile(
            '$processCount',
            'Processes',
            scheme.primary,
            () => context.goNamed('processes'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: tile(
            '$networkCount',
            'Net Conns',
            scheme.tertiary,
            () => context.goNamed('network'),
          ),
        ),
      ],
    );
  }

  /// [displaySmall] can be null in some font-loading edge cases; always set color.
  static TextStyle _summaryNumberStyle(ThemeData theme, ColorScheme scheme) {
    final base = theme.textTheme.headlineLarge ??
        theme.textTheme.headlineMedium ??
        theme.textTheme.titleLarge;
    return (base ?? const TextStyle()).copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w900,
      height: 1.1,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    );
  }
}

class _AlertsStrip extends StatelessWidget {
  const _AlertsStrip({required this.count, required this.scheme});

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: scheme.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(EmDesign.radiusMd),
      child: InkWell(
        onTap: () => context.pushNamed('alerts'),
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EmDesign.radiusMd),
            border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: scheme.error, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$count unread alert${count == 1 ? '' : 's'} — tap to review.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerZoneSection extends StatelessWidget {
  const _DangerZoneSection({
    required this.scheme,
    required this.theme,
    required this.radiusCard,
    required this.onIsolate,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final double radiusCard;
  final VoidCallback onIsolate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, size: 24, color: scheme.error),
              const SizedBox(width: 10),
              Text(
                'Danger Zone',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Isolating the machine will terminate all network traffic except for this management console.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onIsolate,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                ),
                elevation: 0,
              ),
              child: Text(
                'Isolate Machine',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardDataBootstrap extends StatefulWidget {
  const _DashboardDataBootstrap();

  @override
  State<_DashboardDataBootstrap> createState() =>
      _DashboardDataBootstrapState();
}

class _DashboardDataBootstrapState extends State<_DashboardDataBootstrap> {
  bool _autoRefreshStarted = false;

  void _onConnected() {
    if (!_autoRefreshStarted) {
      _autoRefreshStarted = true;
      context.read<ActivityHeatmapBloc>().startAutoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectionBloc, EmConnectionState>(
      listenWhen: (prev, curr) => curr.isConnected && !prev.isConnected,
      listener: (context, _) => _onConnected(),
      child: BlocBuilder<ConnectionBloc, EmConnectionState>(
        builder: (context, conn) {
          if (conn.isConnected && !_autoRefreshStarted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onConnected();
            });
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _DashboardActivityHeatmap extends StatelessWidget {
  const _DashboardActivityHeatmap();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityHeatmapBloc, ActivityHeatmapState>(
      builder: (context, st) {
        return ActivityHeatmapCard(
          loading: st.loading,
          buckets: st.buckets,
          loadError: st.loadError,
          onRefresh: () =>
              context.read<ActivityHeatmapBloc>().refresh(hours: 24),
        );
      },
    );
  }
}

class _DashboardThreatIntelCard extends StatelessWidget {
  const _DashboardThreatIntelCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return BlocBuilder<ThreatIntelBloc, ThreatIntelState>(
      builder: (context, ti) {
        if (ti.loading &&
            !ti.statusLoaded &&
            (ti.lastError == null || ti.lastError!.isEmpty)) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: EmDesign.cardShell(scheme),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loading threat intelligence…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        if (!ti.statusLoaded &&
            !ti.loading &&
            ti.entryCount == 0 &&
            (ti.lastError == null || ti.lastError!.isEmpty)) {
          return const SizedBox.shrink();
        }
        return Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(EmDesign.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(EmDesign.radiusLg),
            onTap: () => context.go('/network?threats=1'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.gpp_maybe_outlined, color: scheme.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THREAT INTEL',
                          style: EmDesign.labelCaps(context, scheme),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ti.entryCount > 0
                              ? '${ti.entryCount} blocklisted IPs loaded\nComparing against network traffic'
                              : ti.lastError != null && ti.lastError!.isNotEmpty
                                  ? 'Threat feeds unavailable'
                                  : 'No blocklisted IPs loaded yet',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (ti.lastError != null && ti.lastError!.isNotEmpty)
                          Text(
                            ti.lastError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.outline),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
