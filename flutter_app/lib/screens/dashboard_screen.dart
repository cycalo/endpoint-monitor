import 'dart:math' show min;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/alerts_bloc.dart';
import '../bloc/connection_bloc.dart';
import '../bloc/process_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../bloc/threat_intel_bloc.dart';
import '../bloc/timeline_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

double _medianOfUnsorted(List<double> values) {
  if (values.isEmpty) return 1;
  final s = List<double>.from(values)..sort();
  final n = s.length;
  if (n.isOdd) return s[n ~/ 2];
  return (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

double _percentile95Unsorted(List<double> values) {
  if (values.isEmpty) return 4;
  final s = List<double>.from(values)..sort();
  final idx = ((s.length - 1) * 0.95).round().clamp(0, s.length - 1);
  return s[idx];
}

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
              return BlocBuilder<AlertsBloc, AlertsState>(
                builder: (context, alerts) {
                  final unacked = alerts.items
                      .where((a) => !alerts.acked.contains(a.id))
                      .length;
                  final hostDisplay = emDisplayConnectionHost(conn.host);
                  final ipLine =
                      _looksLikeIpv4(hostDisplay) ? hostDisplay : '—';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                        const _DashboardDataBootstrap(),
                        const _DashboardConnectionHero(),
                        const SizedBox(height: 20),
                        const _DashboardTimelineChart(),
                        const SizedBox(height: 16),
                        const _DashboardThreatIntelCard(),
                        const SizedBox(height: 24),
                        if (i == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'Waiting for system metrics…',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          _SummaryMetricsPair(
                            processCount: i.processCount,
                            networkCount: i.networkConnectionCount,
                            scheme: scheme,
                            theme: theme,
                            radiusCard: radiusCard,
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, c) {
                              final twoCol = c.maxWidth >= 600;
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
                            _AlertsStrip(count: unacked, scheme: scheme),
                          ],
                          const SizedBox(height: 32),
                          _DangerZoneSection(
                            scheme: scheme,
                            theme: theme,
                            radiusCard: radiusCard,
                            onIsolate: () => _runIsolateFlow(context),
                          ),
                        ],
                      ],
                    ),
                  );
                },
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
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(EmDesign.radiusLg),
            border: EmDesign.ghostBorder(scheme),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('STATUS', style: EmDesign.labelCaps(context, scheme)),
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
                                  color:
                                      scheme.tertiary.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connected',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ] else
                          Text(
                            'Offline',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: scheme.outline,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.isConnected
                          ? 'Secure channel · $host'
                          : 'Use the link control in the header to connect.',
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
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                    border: EmDesign.ghostBorder(scheme),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.monitor_heart_rounded,
                      size: 36,
                      color: scheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
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
                      style: mono.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: scheme.outline,
                      ),
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
          const SizedBox(height: 8),
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

class _RamDiskCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ramFrac = info.ramTotalGb > 0
        ? (info.ramUsedGb / info.ramTotalGb).clamp(0.0, 1.0)
        : 0.0;
    final diskFrac = info.diskTotalGb > 0
        ? (info.diskUsedGb / info.diskTotalGb).clamp(0.0, 1.0)
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Disk (C:)', style: body?.copyWith(color: scheme.onSurface)),
              Text(
                _diskLine(info),
                style: body?.copyWith(color: scheme.tertiary),
              ),
            ],
          ),
              const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: diskFrac,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerLow,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  static String _ramLine(SystemInfo i) {
    if (i.ramTotalGb <= 0) return '—';
    return '${i.ramUsedGb.toStringAsFixed(1)} GB / ${i.ramTotalGb.toStringAsFixed(0)} GB';
  }

  static String _diskLine(SystemInfo i) {
    final u = i.diskUsedGb;
    final t = i.diskTotalGb;
    if (t <= 0) return '—';
    if (t >= 1024) {
      return '${(u / 1024).toStringAsFixed(1)} TB / ${(t / 1024).toStringAsFixed(1)} TB';
    }
    return '${u.toStringAsFixed(0)} GB / ${t.toStringAsFixed(0)} GB';
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
          _infoRow('UPTIME', uptimeLine, valueMono: true),
          _infoRow('PATCH LEVEL', _patchValue(patch, isLatest)),
          _infoRow('LAST BOOT', _dash(info.lastBootTime), valueMono: true),
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
    Widget tile(String value, String label, Color accent) {
      return Container(
        clipBehavior: Clip.antiAlias,
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
                  Text(label.toUpperCase(), style: sub),
                ],
              ),
            ),
                      ],
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
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: tile(
            '$networkCount',
            'Net Conns',
            scheme.tertiary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count unread alert${count == 1 ? '' : 's'} — open Alerts for details.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
                        ],
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
            'Isolating the machine will terminate all network traffic except for this management console. Use only in case of suspected compromise.',
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
  State<_DashboardDataBootstrap> createState() => _DashboardDataBootstrapState();
}

class _DashboardDataBootstrapState extends State<_DashboardDataBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tl = context.read<TimelineBloc>();
      tl.refresh();
      tl.startAutoRefresh();
      context.read<ThreatIntelBloc>()
        ..refreshStatus()
        ..refreshEntries();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DashboardTimelineChart extends StatelessWidget {
  const _DashboardTimelineChart();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (context, st) {
        if (st.loading && st.buckets.isEmpty) {
          return SizedBox(
            height: 160,
            child: Center(
              child: Text(
                'Loading activity timeline…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        if (st.buckets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(EmDesign.radiusLg),
              border: EmDesign.ghostBorder(scheme),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ACTIVITY (24H, UTC HOURS)',
                        style: EmDesign.labelCaps(context, scheme),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () =>
                          context.read<TimelineBloc>().refresh(hours: 24),
                      icon:
                          Icon(Icons.refresh_rounded, color: scheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'No timeline data yet. Connect to the endpoint and wait for activity, then refresh.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final allSeg = <double>[];
        for (final b in st.buckets) {
          allSeg.add(b.processCreate.toDouble());
          allSeg.add(b.networkConnect.toDouble());
          allSeg.add(b.dnsQuery.toDouble());
          allSeg.add(b.alerts.toDouble());
        }
        var median = _medianOfUnsorted(allSeg);
        if (median <= 0) median = 1;
        final p95 = _percentile95Unsorted(allSeg);
        var anyCapped = false;
        double capSeg(double v) {
          final lim = 3 * median;
          final c = min(v, lim);
          if (c < v - 1e-9) anyCapped = true;
          return c;
        }

        var maxStack = 4.0;
        final groups = <BarChartGroupData>[];
        for (var i = 0; i < st.buckets.length; i++) {
          final b = st.buckets[i];
          final p = b.processCreate.toDouble();
          final n = b.networkConnect.toDouble();
          final d = b.dnsQuery.toDouble();
          final a = b.alerts.toDouble();
          final total = p + n + d + a;
          if (total < 0.5) {
            groups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: 0.4,
                    width: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            );
            continue;
          }
          final pc = capSeg(p);
          final nc = capSeg(n);
          final dc = capSeg(d);
          final ac = capSeg(a);
          final totalC = pc + nc + dc + ac;
          if (totalC > maxStack) maxStack = totalC;
          groups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: totalC,
                  width: 10,
                  borderRadius: BorderRadius.circular(2),
                  rodStackItems: [
                    BarChartRodStackItem(0, pc, scheme.primary),
                    BarChartRodStackItem(pc, pc + nc, scheme.tertiary),
                    BarChartRodStackItem(pc + nc, pc + nc + dc, scheme.secondary),
                    BarChartRodStackItem(
                        pc + nc + dc, pc + nc + dc + ac, scheme.error),
                  ],
                ),
              ],
            ),
          );
        }
        final rawMaxY = (maxStack < p95 ? p95 : maxStack) * 1.05;
        final chartMaxY = rawMaxY < 4 ? 4.0 : rawMaxY;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(EmDesign.radiusLg),
            border: EmDesign.ghostBorder(scheme),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ACTIVITY (24H, UTC HOURS)',
                      style: EmDesign.labelCaps(context, scheme),
                    ),
                  ),
                  IconButton(
                    tooltip: 'How to use this chart',
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Activity timeline'),
                          content: const Text(
                            'Tap the red (alerts) segment on a bar to open the Events screen for that UTC hour.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: Icon(Icons.info_outline_rounded, color: scheme.outline),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () =>
                        context.read<TimelineBloc>().refresh(hours: 24),
                    icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _LegendDot(color: scheme.primary, label: 'Process'),
                  const SizedBox(width: 12),
                  _LegendDot(color: scheme.tertiary, label: 'Network'),
                  const SizedBox(width: 12),
                  _LegendDot(color: scheme.secondary, label: 'DNS'),
                  const SizedBox(width: 12),
                  _LegendDot(color: scheme.error, label: 'Alerts'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: chartMaxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: chartMaxY > 20 ? 5 : 1,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, m) => Text(
                            v.toInt().toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) {
                            final i = v.toInt();
                            if (i < 0 || i >= st.buckets.length) {
                              return const SizedBox.shrink();
                            }
                            if (i % 4 != 0) {
                              return const SizedBox.shrink();
                            }
                            final iso = st.buckets[i].hourStartIso;
                            final t = DateTime.tryParse(iso)?.toUtc();
                            final label = t == null
                                ? '$i'
                                : '${t.hour.toString().padLeft(2, '0')}h';
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 8,
                                  color: scheme.outline,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (groupIndex < 0 ||
                              groupIndex >= st.buckets.length) {
                            return null;
                          }
                          final b = st.buckets[groupIndex];
                          return BarTooltipItem(
                            'P ${b.processCreate} · N ${b.networkConnect} · D ${b.dnsQuery} · A ${b.alerts}',
                            TextStyle(
                              color: scheme.onInverseSurface,
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                      handleBuiltInTouches: true,
                      touchCallback: (event, resp) {
                        if (!event.isInterestedForInteractions) return;
                        final spot = resp?.spot;
                        if (spot == null) return;
                        final i = spot.touchedBarGroupIndex;
                        if (i < 0 || i >= st.buckets.length) return;
                        final seg = spot.touchedRodDataIndex;
                        if (seg != 3) return;
                        final hour = st.buckets[i].hourStartIso;
                        context.go(
                          '/events?hour=${Uri.encodeComponent(hour)}',
                        );
                      },
                    ),
                    barGroups: groups,
                  ),
                ),
              ),
              if (anyCapped) ...[
                const SizedBox(height: 6),
                Text(
                  'Some values capped for readability',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
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
        if (ti.entryCount == 0 && (ti.lastError == null || ti.lastError!.isEmpty)) {
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
                          '${ti.entryCount} blocklisted IPs loaded',
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
