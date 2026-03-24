import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/alerts_bloc.dart';
import '../bloc/connection_bloc.dart';
import '../bloc/process_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../models/ws_models.dart';
import '../widgets/em_brand_app_bar.dart';

/// Bento-style dashboard (HTML mock): stats strip, 2×2 metrics, identity + critical control.
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
    const radiusSm = 2.0;

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
                  final ipLine = _looksLikeIpv4(hostDisplay) ? hostDisplay : '—';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 880;
                        final statCards = _DashboardStatsRow(
                          processCount: i?.processCount ?? 0,
                          networkCount: i?.networkConnectionCount ?? 0,
                          alertCount: unacked,
                          mono: mono,
                          radiusSm: radiusSm,
                        );
                        final metrics = i == null
                            ? Padding(
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
                            : _MetricsGrid(
                                info: i,
                                mono: mono,
                                scheme: scheme,
                                radiusSm: radiusSm,
                              );
                        final sidebar = _SidebarColumn(
                          info: i,
                          hostDisplay: hostDisplay,
                          ipLine: ipLine,
                          mono: mono,
                          scheme: scheme,
                          theme: theme,
                          radiusSm: radiusSm,
                          onIsolate: () => _runIsolateFlow(context),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            statCards,
                            const SizedBox(height: 24),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 8, child: metrics),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 4, child: sidebar),
                                ],
                              )
                            else ...[
                              metrics,
                              const SizedBox(height: 20),
                              sidebar,
                            ],
                          ],
                        );
                      },
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
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
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
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Isolate')),
        ],
      ),
    );
    if (ok2 == true && context.mounted) {
      proc.sendCommand({'type': 'isolate_machine'});
    }
  }
}

class _DashboardStatsRow extends StatelessWidget {
  const _DashboardStatsRow({
    required this.processCount,
    required this.networkCount,
    required this.alertCount,
    required this.mono,
    required this.radiusSm,
  });

  final int processCount;
  final int networkCount;
  final int alertCount;
  final TextStyle mono;
  final double radiusSm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headline = GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    Widget card({
      required String label,
      required String value,
      required IconData icon,
      required Color valueColor,
      bool pulse = false,
    }) {
      return Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: mono.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: label.contains('Alert') ? scheme.error : scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(value, style: headline.copyWith(color: valueColor)),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 28, color: valueColor.withValues(alpha: 0.45)),
                  if (pulse)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: card(
                  label: 'Active Processes',
                  value: '$processCount',
                  icon: Icons.memory_rounded,
                  valueColor: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: card(
                  label: 'Network Connections',
                  value: '$networkCount',
                  icon: Icons.lan_rounded,
                  valueColor: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: card(
                  label: 'New Alerts',
                  value: '$alertCount',
                  icon: Icons.warning_amber_rounded,
                  valueColor: scheme.error,
                  pulse: alertCount > 0,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            card(
              label: 'Active Processes',
              value: '$processCount',
              icon: Icons.memory_rounded,
              valueColor: scheme.onSurface,
            ),
            const SizedBox(height: 10),
            card(
              label: 'Network Connections',
              value: '$networkCount',
              icon: Icons.lan_rounded,
              valueColor: scheme.onSurface,
            ),
            const SizedBox(height: 10),
            card(
              label: 'New Alerts',
              value: '$alertCount',
              icon: Icons.warning_amber_rounded,
              valueColor: scheme.error,
              pulse: alertCount > 0,
            ),
          ],
        );
      },
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.info,
    required this.mono,
    required this.scheme,
    required this.radiusSm,
  });

  final SystemInfo info;
  final TextStyle mono;
  final ColorScheme scheme;
  final double radiusSm;

  static const _spark = [0.35, 0.5, 0.7, 0.45, 0.9, 0.65, 0.8, 0.95];

  @override
  Widget build(BuildContext context) {
    final cpu = info.cpuPercent.clamp(0, 100);
    final ramFrac = info.ramTotalGb > 0
        ? (info.ramUsedGb / info.ramTotalGb).clamp(0.0, 1.0)
        : 0.0;
    final diskFrac = info.diskTotalGb > 0
        ? (info.diskUsedGb / info.diskTotalGb).clamp(0.0, 1.0)
        : 0.0;
    final diskPct = (diskFrac * 100).round();
    final freeGb =
        (info.diskTotalGb - info.diskUsedGb).clamp(0, double.infinity);
    String diskTotalLabel() {
      final t = info.diskTotalGb;
      if (t >= 1024) return '${(t / 1024).toStringAsFixed(1)} TB TOTAL';
      return '${t.toStringAsFixed(0)} GB TOTAL';
    }

    final headline = GoogleFonts.spaceGrotesk(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    Widget metricShell({required List<Widget> children}) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth >= 420;
        final children = [
          metricShell(
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
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
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
                                  fontSize: 16,
                                  color: scheme.primary.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.speed_rounded, color: scheme.primary, size: 28),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: scheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(8, (i) {
                        final base = _spark[i];
                        final h = 48 * base * (0.45 + cpu / 130);
                        final op = 0.2 + (i / 8) * 0.45;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              height: h.clamp(8, 52),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: op),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          metricShell(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEMORY ALLOCATION',
                          style: mono.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: info.ramUsedGb.toStringAsFixed(1),
                                style: headline.copyWith(fontSize: 32),
                              ),
                              TextSpan(
                                text: ' / ${info.ramTotalGb.toStringAsFixed(0)} GB',
                                style: headline.copyWith(
                                  fontSize: 15,
                                  color: scheme.primary.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.memory_rounded, color: scheme.primary, size: 28),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ramFrac,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerLowest,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            ],
          ),
          metricShell(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DISK USAGE (C:)',
                          style: mono.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$diskPct',
                                style: headline.copyWith(fontSize: 32),
                              ),
                              TextSpan(
                                text: '%',
                                style: headline.copyWith(
                                  fontSize: 15,
                                  color: scheme.primary.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.storage_rounded, color: scheme.primary, size: 28),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${freeGb.toStringAsFixed(0)} GB FREE',
                    style: mono.copyWith(fontSize: 9, color: scheme.outline),
                  ),
                  Text(
                    diskTotalLabel(),
                    style: mono.copyWith(fontSize: 9, color: scheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: diskFrac,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerLowest,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            ],
          ),
          metricShell(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SYSTEM UPTIME',
                          style: mono.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info.uptime.isEmpty ? '—' : info.uptime,
                          style: headline.copyWith(fontSize: 26),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.update_rounded, color: scheme.primary, size: 28),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    info.lastBootTime.trim().isEmpty
                        ? 'LAST REBOOT: —'
                        : 'LAST REBOOT: ${info.lastBootTime}',
                    style: mono.copyWith(
                      fontSize: 9,
                      color: scheme.tertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ];

        if (!twoCol) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                children[i],
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 14),
                Expanded(child: children[1]),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[2]),
                const SizedBox(width: 14),
                Expanded(child: children[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SidebarColumn extends StatelessWidget {
  const _SidebarColumn({
    required this.info,
    required this.hostDisplay,
    required this.ipLine,
    required this.mono,
    required this.scheme,
    required this.theme,
    required this.radiusSm,
    required this.onIsolate,
  });

  final SystemInfo? info;
  final String hostDisplay;
  final String ipLine;
  final TextStyle mono;
  final ColorScheme scheme;
  final ThemeData theme;
  final double radiusSm;
  final VoidCallback onIsolate;

  static String _dash(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? '—' : t;
  }

  @override
  Widget build(BuildContext context) {
    final patch = info?.patchLevel ?? '';
    final isLatest = patch.isNotEmpty && patch.toLowerCase().contains('latest');
    final i = info;
    final usersLine = i == null || i.loggedInUsers.isEmpty
        ? '—'
        : '${i.loggedInUsers.take(5).join(', ')}${i.loggedInUsers.length > 5 ? '…' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(radiusSm),
            border: Border(left: BorderSide(color: scheme.primary, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SYSTEM IDENTITY',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              _identityRow(
                context,
                'System Name',
                _dash(info?.systemName),
                valueMono: true,
              ),
              _identityRow(context, 'OS Version', _dash(info?.osDisplayLine)),
              _identityRow(context, 'Architecture', _dash(info?.osArchitecture)),
              _patchRow(context, patch, isLatest),
              _identityRow(
                context,
                'Domain / Workgroup',
                _dash(info?.domain),
              ),
              _identityRow(
                context,
                'Last Boot',
                _dash(info?.lastBootTime),
                valueMono: true,
              ),
              _identityRow(context, 'IP Address', ipLine, valueMono: true),
              if (hostDisplay != '—' && ipLine == '—')
                _identityRow(context, 'Mgmt Endpoint', hostDisplay, valueMono: true),
              _identityRow(context, 'Logged-in Users', usersLine),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radiusSm),
            border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dangerous_rounded, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'CRITICAL CONTROL',
                    style: mono.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: scheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Isolating the machine will terminate all external networking protocols except for this secure management channel.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onIsolate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.85)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'ISOLATE MACHINE',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _patchRow(BuildContext context, String patch, bool isLatest) {
    Widget value;
    if (patch.isEmpty) {
      value = Text('—', style: theme.textTheme.bodySmall);
    } else if (isLatest) {
      value = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: scheme.tertiary),
          const SizedBox(width: 4),
          Text('Latest', style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary)),
        ],
      );
    } else {
      value = Text(patch, style: theme.textTheme.bodySmall);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PATCH LEVEL',
                style: mono.copyWith(fontSize: 10, color: scheme.outline),
              ),
              Flexible(child: value),
            ],
          ),
          Divider(height: 12, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.1)),
        ],
      ),
    );
  }

  Widget _identityRow(
    BuildContext context,
    String label,
    String value, {
    bool valueMono = false,
  }) {
    final vStyle = valueMono
        ? mono.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface)
        : theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label.toUpperCase(),
                style: mono.copyWith(fontSize: 10, color: scheme.outline),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: vStyle,
                ),
              ),
            ],
          ),
          Divider(height: 12, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.1)),
        ],
      ),
    );
  }
}
