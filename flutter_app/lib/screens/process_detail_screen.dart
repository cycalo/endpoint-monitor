import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/events_bloc.dart';
import '../bloc/process_bloc.dart';
import '../bloc/watchlist_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/process_control_buttons.dart';
import '../widgets/process_virus_total_sheet.dart';
import '../widgets/process_watchlist_flag_action.dart';

ProcessInfo? _snapshotForPid(ProcessState s, int pid, bool ghost) {
  if (ghost) {
    for (final g in s.killedGhosts) {
      if (g.pid == pid) return g.snapshot;
    }
    return null;
  }
  for (final p in s.items) {
    if (p.pid == pid) return p;
  }
  return null;
}

DateTime? _killedAtForPid(ProcessState s, int pid) {
  for (final g in s.killedGhosts) {
    if (g.pid == pid) return g.killedAt;
  }
  return null;
}

/// Process detail: stable overview (selection-friendly) + Sysmon events.
/// Opened from the process list so live list refreshes do not rebuild this subtree.
class ProcessDetailScreen extends StatelessWidget {
  const ProcessDetailScreen({
    super.key,
    required this.pid,
    this.isKilledGhostSnapshot = false,
  });

  final int pid;
  final bool isKilledGhostSnapshot;

  static const _highCpuWarn = 40.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono =
        GoogleFonts.jetBrainsMono(color: scheme.onSurfaceVariant, fontSize: 11);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: BlocSelector<ProcessBloc, ProcessState, String>(
            selector: (s) =>
                _snapshotForPid(s, pid, isKilledGhostSnapshot)?.name ?? '',
            builder: (context, name) => Text(
              name.trim().isEmpty ? 'PID $pid' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Sysmon'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(
              pid: pid,
              isKilledGhost: isKilledGhostSnapshot,
              mono: mono,
            ),
            _SysmonEventsTab(pid: pid),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.pid,
    required this.isKilledGhost,
    required this.mono,
  });

  final int pid;
  final bool isKilledGhost;
  final TextStyle mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocSelector<ProcessBloc, ProcessState, bool>(
      selector: (s) =>
          s.loading && _snapshotForPid(s, pid, isKilledGhost) == null,
      builder: (context, showSpinner) {
        if (showSpinner) {
          return const Center(child: CircularProgressIndicator());
        }
        return BlocSelector<ProcessBloc, ProcessState, bool>(
          selector: (s) => _snapshotForPid(s, pid, isKilledGhost) != null,
          builder: (context, exists) {
            if (!exists) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isKilledGhost
                        ? 'This killed-process entry is no longer available. It may have been dismissed or the list refreshed.'
                        : 'This process is not in the current snapshot. It may have exited.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlocSelector<ProcessBloc, ProcessState, String>(
                    selector: (s) {
                      final p = _snapshotForPid(s, pid, isKilledGhost);
                      return p == null ? '' : 'PID ${p.pid}';
                    },
                    builder: (context, pidLine) {
                      if (pidLine.isEmpty) return const SizedBox.shrink();
                      return Text(
                        pidLine,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                  if (isKilledGhost) ...[
                    const SizedBox(height: 8),
                    BlocSelector<ProcessBloc, ProcessState, DateTime?>(
                      selector: (s) => _killedAtForPid(s, pid),
                      builder: (context, killedAt) {
                        if (killedAt == null) return const SizedBox.shrink();
                        return Text(
                          'Killed at ${killedAt.toLocal()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  BlocSelector<ProcessBloc, ProcessState, (double, double)>(
                    selector: (s) {
                      final p = _snapshotForPid(s, pid, isKilledGhost)!;
                      return (p.cpuPercent, p.memoryMb);
                    },
                    builder: (context, pair) {
                      final (cpu, ram) = pair;
                      return Row(
                        children: [
                          Icon(Icons.memory_rounded,
                              size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            '${cpu.toStringAsFixed(1)}% CPU',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Icon(Icons.storage_rounded,
                              size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            '${ram.toStringAsFixed(0)} MB RAM',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'COMMAND LINE',
                    style: EmDesign.labelCaps(context, scheme),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                    ),
                    child: BlocSelector<ProcessBloc, ProcessState, String>(
                      selector: (s) {
                        final p = _snapshotForPid(s, pid, isKilledGhost);
                        return p?.commandLine ?? '';
                      },
                      builder: (context, cmd) {
                        return SelectableText(
                          cmd.isEmpty ? '(no command line)' : cmd,
                          style: mono.copyWith(
                            fontSize: 12,
                            color: scheme.primary.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PARENT PID',
                              style: EmDesign.labelCaps(context, scheme),
                            ),
                            const SizedBox(height: 4),
                            BlocSelector<ProcessBloc, ProcessState, int>(
                              selector: (s) {
                                final p = _snapshotForPid(s, pid, isKilledGhost);
                                return p?.parentPid ?? 0;
                              },
                              builder: (context, ppid) {
                                return Text(
                                  '$ppid',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STATUS',
                              style: EmDesign.labelCaps(context, scheme),
                            ),
                            const SizedBox(height: 4),
                            BlocSelector<ProcessBloc, ProcessState, (String, bool)>(
                              selector: (s) {
                                final p = _snapshotForPid(s, pid, isKilledGhost);
                                final st = p?.status ?? '';
                                final susp = !isKilledGhost &&
                                    (s.suspendedPids.contains(pid) ||
                                        st.toLowerCase().contains('suspend'));
                                return (st, susp);
                              },
                              builder: (context, pair) {
                                final (status, suspended) = pair;
                                final label = isKilledGhost
                                    ? 'Killed'
                                    : suspended
                                        ? 'Suspended'
                                        : (status.isEmpty
                                            ? 'Running'
                                            : status);
                                final color = isKilledGhost
                                    ? scheme.error
                                    : suspended
                                        ? scheme.outline
                                        : scheme.tertiary;
                                return Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.45),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        label,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'ACTIONS',
                    style: EmDesign.labelCaps(context, scheme),
                  ),
                  const SizedBox(height: 12),
                  BlocSelector<ProcessBloc, ProcessState, ProcessInfo?>(
                    selector: (s) => _snapshotForPid(s, pid, isKilledGhost),
                    builder: (context, p) {
                      if (p == null) return const SizedBox.shrink();
                      final suspended = !isKilledGhost &&
                          context.select<ProcessBloc, bool>(
                            (bloc) =>
                                bloc.state.suspendedPids.contains(pid) ||
                                p.status.toLowerCase().contains('suspend'),
                          );
                      final highCpu =
                          !isKilledGhost && p.cpuPercent > ProcessDetailScreen._highCpuWarn;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ProcessKillInkButton(
                            onPressed: isKilledGhost
                                ? null
                                : () => confirmKillProcess(context, p),
                            label: isKilledGhost ? 'Killed' : 'Kill',
                            enabled: !isKilledGhost,
                          ),
                          Opacity(
                            opacity: isKilledGhost || suspended ? 0.4 : 1,
                            child: ProcessOutlineInkButton(
                              scheme: scheme,
                              icon: Icons.pause_circle_outline_rounded,
                              label: 'Suspend',
                              dimmed: isKilledGhost || suspended,
                              onPressed: isKilledGhost || suspended
                                  ? null
                                  : () => context.read<ProcessBloc>().sendCommand({
                                        'type': 'suspend_process',
                                        'pid': p.pid,
                                      }),
                            ),
                          ),
                          Opacity(
                            opacity: isKilledGhost || !suspended ? 0.4 : 1,
                            child: ProcessOutlineInkButton(
                              scheme: scheme,
                              icon: Icons.play_circle_outline_rounded,
                              label: 'Resume',
                              dimmed: isKilledGhost || !suspended,
                              onPressed: isKilledGhost || !suspended
                                  ? null
                                  : () => context.read<ProcessBloc>().sendCommand({
                                        'type': 'resume_process',
                                        'pid': p.pid,
                                      }),
                            ),
                          ),
                          if (highCpu && !suspended && !isKilledGhost)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 16, color: scheme.error),
                                  const SizedBox(width: 4),
                                  Text(
                                    'High CPU',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          BlocBuilder<WatchlistBloc, WatchlistState>(
                            buildWhen: (prev, next) =>
                                prev.entries != next.entries,
                            builder: (context, wl) {
                              final normalized =
                                  WatchlistBloc.normalizeExecutableName(p.name);
                              final flagged = normalized != null &&
                                  wl.entries.any((e) =>
                                      e.name.toLowerCase() ==
                                      normalized.toLowerCase());
                              final amber = const Color(0xFFE65100);
                              return OutlinedButton.icon(
                                onPressed: isKilledGhost
                                    ? null
                                    : () => processWatchlistFlagTap(
                                          context,
                                          p,
                                          flagged,
                                        ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      flagged ? amber : scheme.outline,
                                  side: BorderSide(
                                    color: flagged
                                        ? amber.withValues(alpha: 0.65)
                                        : scheme.outlineVariant
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                icon: Icon(
                                  flagged
                                      ? Icons.flag_rounded
                                      : Icons.flag_outlined,
                                  size: 18,
                                ),
                                label: Text(flagged ? 'Flagged' : 'Flag'),
                              );
                            },
                          ),
                          OutlinedButton.icon(
                            onPressed: isKilledGhost
                                ? null
                                : () => openProcessVirusTotalSheet(context, p),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.primary,
                              side: BorderSide(
                                color: scheme.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            icon: const Icon(Icons.shield_outlined, size: 18),
                            label: const Text('VirusTotal'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SysmonEventsTab extends StatelessWidget {
  const _SysmonEventsTab({required this.pid});

  final int pid;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EventsBloc, EventsState>(
      builder: (context, state) {
        final items = state.items.where((e) => e.pid == pid).toList();
        final cs = Theme.of(context).colorScheme;
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No Sysmon events for this PID yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final e = items[i];
            return Material(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
              child: ListTile(
                title: Text(e.type),
                subtitle: Text(e.timestamp),
              ),
            );
          },
        );
      },
    );
  }
}
