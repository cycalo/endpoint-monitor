import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/connection_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../bloc/system_vitals_history_cubit.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../utils/em_snapshot_cache.dart';
import '../utils/em_vital_band.dart';
import '../widgets/em_gradient_button.dart';
import '../widgets/em_loading_states.dart';
import '../widgets/system_monitor/em_vital_detail_sheet.dart';
import '../widgets/system_monitor/em_vital_tile.dart';
import '../widgets/system_monitor/em_vitals_grid.dart';
import '../widgets/system_monitor/em_vitals_hero.dart';

/// Full-screen live vitals mode — reads only SystemInfoBloc + ConnectionBloc.
class SystemMonitorScreen extends StatefulWidget {
  const SystemMonitorScreen({super.key});

  @override
  State<SystemMonitorScreen> createState() => _SystemMonitorScreenState();
}

class _SystemMonitorScreenState extends State<SystemMonitorScreen> {
  Timer? _uptimeTimer;
  Duration? _uptimeBaseline;
  DateTime? _uptimeReceivedAt;
  String _uptimeFallback = '—';

  @override
  void initState() {
    super.initState();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: scheme.surface,
          statusBarIconBrightness: scheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      );
    });
  }

  @override
  void dispose() {
    _uptimeTimer?.cancel();
    super.dispose();
  }

  void _syncUptime(SystemInfo? info) {
    if (info == null) return;
    final parsed = emParseAgentUptime(info.uptime);
    if (parsed != null) {
      _uptimeBaseline = parsed;
      _uptimeReceivedAt = DateTime.now();
      _uptimeFallback = '';
    } else if (info.uptime.trim().isNotEmpty) {
      _uptimeFallback = info.uptime.trim();
      _uptimeBaseline = null;
    }
  }

  String _liveUptime() {
    if (_uptimeBaseline != null && _uptimeReceivedAt != null) {
      final elapsed = DateTime.now().difference(_uptimeReceivedAt!);
      return emFormatUptimeDuration(_uptimeBaseline! + elapsed);
    }
    return _uptimeFallback;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: EmVitalsGrid(
        child: SafeArea(
          child: BlocBuilder<ConnectionBloc, EmConnectionState>(
            builder: (context, conn) {
              return BlocBuilder<SystemInfoBloc, SystemInfoState>(
                builder: (context, si) {
                  _syncUptime(si.info);
                  return BlocBuilder<SystemVitalsHistoryCubit,
                      SystemVitalsHistoryState>(
                    builder: (context, hist) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _VitalsHeader(
                            connected: conn.isConnected,
                            connecting:
                                conn.status == ConnectionStatus.connecting,
                          ),
                          Expanded(
                            child: si.info == null
                                ? const Center(
                                    child: EmStatusPanel(
                                      loading: true,
                                      message: 'Syncing system vitals…',
                                    ),
                                  )
                                : _VitalsBody(
                                    info: si.info!,
                                    history: hist.samples,
                                    uptime: _liveUptime(),
                                    connected: conn.isConnected,
                                    fromCache: si.fromCache,
                                    onTileTap: (kind) => showVitalDetailSheet(
                                      context: context,
                                      kind: kind,
                                      info: si.info!,
                                      cpuHistory: hist.samples
                                          .map((s) => s.cpuPercent)
                                          .toList(),
                                      ramHistory: hist.samples
                                          .map((s) => s.ramPercent)
                                          .toList(),
                                      sentHistory: hist.samples
                                          .map((s) => s.bytesSentPerSec)
                                          .toList(),
                                      recvHistory: hist.samples
                                          .map((s) => s.bytesReceivedPerSec)
                                          .toList(),
                                    ),
                                  ),
                          ),
                          if (!conn.isConnected)
                            _DisconnectedBanner(
                              message: conn.message,
                              onReconnect: () => context
                                  .read<ConnectionBloc>()
                                  .add(const ConnectionReconnectRequested()),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VitalsHeader extends StatelessWidget {
  const _VitalsHeader({
    required this.connected,
    required this.connecting,
  });

  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ledColor = connected
        ? scheme.tertiary
        : connecting
            ? scheme.primary
            : scheme.outline;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Exit vitals',
            onPressed: () => context.pop(),
            icon: Icon(Icons.close_rounded, color: scheme.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENDPOINT MONITOR',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: scheme.primary,
                  ),
                ),
                Text('SYSTEM VITALS', style: EmDesign.labelCaps(context, scheme)),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ledColor,
              boxShadow: connected
                  ? [
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalsBody extends StatelessWidget {
  const _VitalsBody({
    required this.info,
    required this.history,
    required this.uptime,
    required this.connected,
    required this.fromCache,
    required this.onTileTap,
  });

  final SystemInfo info;
  final List<SystemVitalsSample> history;
  final String uptime;
  final bool connected;
  final bool fromCache;
  final void Function(VitalTileKind kind) onTileTap;

  @override
  Widget build(BuildContext context) {
    final cpuHistory = history.map((s) => s.cpuPercent).toList();
    final ramHistory = history.map((s) => s.ramPercent).toList();
    final sentHistory = history.map((s) => s.bytesSentPerSec).toList();
    final recvHistory = history.map((s) => s.bytesReceivedPerSec).toList();

    final ramPct = emRamPercent(info.ramUsedGb, info.ramTotalGb);
    final diskPct = emDiskPercent(info.diskUsedGb, info.diskTotalGb);
    final score = emEndpointHealthScore(
      cpuPercent: info.cpuPercent,
      ramPercent: ramPct,
      diskPercent: diskPct,
    );
    final worstBand = emWorstVitalBand(
      cpuPercent: info.cpuPercent,
      ramPercent: ramPct,
      diskPercent: diskPct,
    );

    Widget buildTiles({bool compact = false}) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: compact ? 120 : 140,
                  child: EmVitalTile(
                    kind: VitalTileKind.cpu,
                    info: info,
                    cpuHistory: cpuHistory,
                    ramHistory: ramHistory,
                    sentHistory: sentHistory,
                    recvHistory: recvHistory,
                    onTap: () => onTileTap(VitalTileKind.cpu),
                  ),
                ),
              ),
              const SizedBox(width: EmDesign.spaceMd),
              Expanded(
                child: SizedBox(
                  height: compact ? 120 : 140,
                  child: EmVitalTile(
                    kind: VitalTileKind.ram,
                    info: info,
                    cpuHistory: cpuHistory,
                    ramHistory: ramHistory,
                    sentHistory: sentHistory,
                    recvHistory: recvHistory,
                    onTap: () => onTileTap(VitalTileKind.ram),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EmDesign.spaceMd),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: compact ? 120 : 140,
                  child: EmVitalTile(
                    kind: VitalTileKind.disk,
                    info: info,
                    cpuHistory: cpuHistory,
                    ramHistory: ramHistory,
                    sentHistory: sentHistory,
                    recvHistory: recvHistory,
                    onTap: () => onTileTap(VitalTileKind.disk),
                  ),
                ),
              ),
              const SizedBox(width: EmDesign.spaceMd),
              Expanded(
                child: SizedBox(
                  height: compact ? 120 : 140,
                  child: EmVitalTile(
                    kind: VitalTileKind.network,
                    info: info,
                    cpuHistory: cpuHistory,
                    ramHistory: ramHistory,
                    sentHistory: sentHistory,
                    recvHistory: recvHistory,
                    onTap: () => onTileTap(VitalTileKind.network),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final identityStrip = _IdentityStrip(
      uptime: uptime,
      sysmon: info.sysmonStatus,
      agentVersion: info.agentVersion,
      processCount: info.processCount,
      connectionCount: info.networkConnectionCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape =
            constraints.maxWidth >= 700 || constraints.maxWidth > constraints.maxHeight;

        if (landscape) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              EmDesign.spaceMd,
              0,
              EmDesign.spaceMd,
              EmDesign.spaceMd,
            ),
            child: Column(
              children: [
                if (fromCache && !connected)
                  FutureBuilder<DateTime?>(
                    future: EmSnapshotCache.systemInfoCachedAt(),
                    builder: (context, snap) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: EmStaleSnapshotBanner(cachedAt: snap.data),
                      );
                    },
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            EmVitalsHero(
                              healthScore: score,
                              worstBand: worstBand,
                              cpuHistory: cpuHistory,
                              compact: true,
                            ),
                            identityStrip,
                          ],
                        ),
                      ),
                      const SizedBox(width: EmDesign.spaceMd),
                      Expanded(flex: 3, child: buildTiles(compact: true)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            EmDesign.spaceMd,
            0,
            EmDesign.spaceMd,
            EmDesign.spaceXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fromCache && !connected)
                FutureBuilder<DateTime?>(
                  future: EmSnapshotCache.systemInfoCachedAt(),
                  builder: (context, snap) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EmStaleSnapshotBanner(cachedAt: snap.data),
                    );
                  },
                ),
              EmVitalsHero(
                healthScore: score,
                worstBand: worstBand,
                cpuHistory: cpuHistory,
              ),
              identityStrip,
              const SizedBox(height: EmDesign.spaceMd),
              buildTiles(),
            ],
          ),
        );
      },
    );
  }
}

class _IdentityStrip extends StatelessWidget {
  const _IdentityStrip({
    required this.uptime,
    required this.sysmon,
    required this.agentVersion,
    required this.processCount,
    required this.connectionCount,
  });

  final String uptime;
  final String sysmon;
  final String agentVersion;
  final int processCount;
  final int connectionCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono(
      fontSize: 11,
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EmDesign.spaceSm),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _chip(context, 'UPTIME', uptime, mono, scheme),
          _chip(context, 'SYSMON', sysmon.isEmpty ? '—' : sysmon, mono, scheme),
          _chip(context, 'AGENT', agentVersion.isEmpty ? '—' : agentVersion, mono, scheme),
          _chip(context, 'PROCS', '$processCount', mono, scheme),
          _chip(context, 'NET CONNS', '$connectionCount', mono, scheme),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    String value,
    TextStyle mono,
    ColorScheme scheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: EmDesign.labelCaps(context, scheme)),
        Text(value, style: mono),
      ],
    );
  }
}

class _DisconnectedBanner extends StatelessWidget {
  const _DisconnectedBanner({
    required this.message,
    required this.onReconnect,
  });

  final String? message;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(EmDesign.spaceMd),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        border: Border(top: EmDesign.ghostBorder(scheme).top),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message?.trim().isNotEmpty == true
                ? message!.trim()
                : 'Connection lost. Reconnect to resume live vitals.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          EmGradientButton(
            label: 'Reconnect',
            onPressed: onReconnect,
          ),
        ],
      ),
    );
  }
}
