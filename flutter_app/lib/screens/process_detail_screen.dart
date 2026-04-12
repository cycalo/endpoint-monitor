import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../bloc/events_bloc.dart';
import '../bloc/network_bloc.dart';
import '../bloc/process_bloc.dart';
import '../bloc/watchlist_bloc.dart';
import '../models/ws_models.dart';
import '../settings/groq_testing_defaults.dart';
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

String _formatSysmonLocalTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso.isEmpty ? '—' : iso;
  return DateFormat('EEE, MMM d, y · HH:mm:ss').format(parsed.toLocal());
}

String _sysmonEventTypeLabel(String type) {
  if (type.isEmpty) return 'Event';
  const known = <String, String>{
    'DnsQuery': 'DNS query',
    'NetworkConnect': 'Network connection',
    'ProcessCreate': 'Process created',
    'ProcessTerminate': 'Process terminated',
    'FileCreate': 'File created',
    'FileDelete': 'File deleted',
    'ImageLoad': 'Image loaded',
    'DriverLoad': 'Driver loaded',
    'CreateRemoteThread': 'Remote thread',
    'RawAccessRead': 'Raw disk access',
    'ProcessAccess': 'Process access',
    'FileCreateTime': 'File timestamp changed',
    'RegistryEvent': 'Registry',
    'FileCreateStreamHash': 'File stream / hash',
    'PipeEvent': 'Named pipe',
    'WmiEvent': 'WMI',
    'ClipboardChange': 'Clipboard',
    'ProcessTampering': 'Process tampering',
    'FileExecutableDetected': 'Executable detected',
  };
  return known[type] ?? _pascalCaseToTitle(type);
}

String _pascalCaseToTitle(String s) {
  final spaced = s.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m[1]} ${m[2]}',
  );
  return spaced.split(RegExp(r'\s+')).map((w) {
    if (w.isEmpty) return w;
    final lower = w.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }).join(' ');
}

String? _sysmonEventContextLine(SysmonEvent e) {
  final dns = e.dnsQuery?.trim();
  if (dns != null && dns.isNotEmpty) return dns;

  final host = e.remoteAddress?.trim();
  if (host != null && host.isNotEmpty) {
    final port = e.remotePort != null && e.remotePort! > 0 ? ':${e.remotePort}' : '';
    return '$host$port';
  }

  final cmd = e.commandLine?.trim();
  if (cmd != null && cmd.isNotEmpty) {
    return cmd.length > 140 ? '${cmd.substring(0, 137)}…' : cmd;
  }
  return null;
}

/// Visual line count after wrapping at [maxWidth] (handles long single-line commands).
int _wrappedLineCount(
  String text,
  TextStyle style,
  double maxWidth,
  TextDirection direction,
) {
  if (text.isEmpty) return 1;
  if (!maxWidth.isFinite || maxWidth <= 0) return 1;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
  );
  painter.layout(maxWidth: maxWidth);
  final metrics = painter.computeLineMetrics();
  return metrics.isEmpty ? 1 : metrics.length;
}

class _ExpandableCommandLineBlock extends StatefulWidget {
  const _ExpandableCommandLineBlock({
    super.key,
    required this.cmd,
    required this.mono,
    required this.textColor,
  });

  final String cmd;
  final TextStyle mono;
  final Color textColor;

  @override
  State<_ExpandableCommandLineBlock> createState() =>
      _ExpandableCommandLineBlockState();
}

class _ExpandableCommandLineBlockState extends State<_ExpandableCommandLineBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final direction = Directionality.of(context);
    final display =
        widget.cmd.isEmpty ? '(no command line)' : widget.cmd;
    final style = widget.mono.copyWith(
      fontSize: 12,
      color: widget.textColor,
      height: 1.4,
    );

    if (widget.cmd.isEmpty) {
      return SelectionArea(child: Text(display, style: style));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final lines = _wrappedLineCount(widget.cmd, style, w, direction);
        final needsExpand = lines > 5;

        if (!needsExpand) {
          return SelectionArea(child: Text(display, style: style));
        }

        final extraLines = lines - 5;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: SelectionArea(
                child: Text(
                  display,
                  style: style,
                  maxLines: _expanded ? null : 5,
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(
                  _expanded
                      ? 'Show less'
                      : 'Show more ($extraLines more '
                          '${extraLines == 1 ? 'line' : 'lines'})',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
          selector: (s) {
            final exists = _snapshotForPid(s, pid, isKilledGhost) != null;
            if (!exists) {
              _explainCache.remove(pid);
            }
            return exists;
          },
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
                        return _ExpandableCommandLineBlock(
                          key: ValueKey(cmd),
                          cmd: cmd,
                          mono: mono,
                          textColor:
                              scheme.primary.withValues(alpha: 0.85),
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
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
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
                                  final watchYellow = const Color(0xFFF0B429);
                                  final watchYellowOnLight =
                                      const Color(0xFF4A3D00);
                                  final watchYellowOnDark =
                                      const Color(0xFFFFE082);
                                  final dark = theme.brightness == Brightness.dark;
                                  return OutlinedButton.icon(
                                    onPressed: isKilledGhost
                                        ? null
                                        : () => processWatchlistFlagTap(
                                              context,
                                              p.name,
                                              flagged,
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: flagged
                                          ? (dark
                                              ? watchYellowOnDark
                                              : watchYellowOnLight)
                                          : scheme.primary,
                                      backgroundColor: flagged
                                          ? watchYellow.withValues(alpha: dark ? 0.22 : 0.2)
                                          : null,
                                      side: BorderSide(
                                        color: flagged
                                            ? watchYellow
                                            : scheme.primary
                                                .withValues(alpha: 0.55),
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
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
                          ),
                          _ExplainProcessSection(pid: pid, process: p),
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

class ProcessExplanation {
  final String verdict;
  final String verdictReason;
  final String who;
  final String what;
  final String where;
  final String allowed;
  final String path;
  final String behaviour;

  ProcessExplanation({
    required this.verdict,
    required this.verdictReason,
    required this.who,
    required this.what,
    required this.where,
    required this.allowed,
    required this.path,
    required this.behaviour,
  });

  factory ProcessExplanation.fromJson(Map<String, dynamic> json) {
    return ProcessExplanation(
      verdict: json['verdict'] as String? ?? 'Unknown',
      verdictReason: json['verdictReason'] as String? ?? '',
      who: json['who'] as String? ?? '',
      what: json['what'] as String? ?? '',
      where: json['where'] as String? ?? '',
      allowed: json['allowed'] as String? ?? '',
      path: json['path'] as String? ?? '',
      behaviour: json['behaviour'] as String? ?? '',
    );
  }
}

class ExplainResult {
  final ProcessExplanation? explanation;
  final String? rawError;
  final DateTime timestamp;
  final bool isError;
  ExplainResult({this.explanation, this.rawError, required this.timestamp, required this.isError});
}

final Map<int, ExplainResult> _explainCache = {};

class _ExplainProcessSection extends StatefulWidget {
  const _ExplainProcessSection({required this.pid, required this.process});
  final int pid;
  final ProcessInfo process;

  @override
  State<_ExplainProcessSection> createState() => _ExplainProcessSectionState();
}

class _ExplainProcessSectionState extends State<_ExplainProcessSection> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _explain() async {
    final netBloc = context.read<NetworkBloc>();
    const storage = FlutterSecureStorage();
    final stored = (await storage.read(key: 'groq_api_key') ?? '').trim();
    final key = stored.isNotEmpty ? stored : kDefaultGroqApiKeyForTesting;

    setState(() => _loading = true);

    final conns = netBloc.state.items.where((c) => c.pid == widget.pid).take(5).toList();
    final connLines = conns.map((c) => '${c.remoteAddress}:${c.remotePort} ${c.protocol} ${c.state}').join('\n');
    final connText = conns.isEmpty ? 'none' : connLines;

    final prompt = '''You are a Windows endpoint security analyst. When given details about a
running Windows process, respond with a JSON object only — no markdown,
no explanation outside the JSON, no code fences. Use exactly this structure:

{
  "verdict": "Safe" | "Suspicious" | "Malicious" | "Unknown",
  "verdictReason": "One sentence summary of why this verdict was reached.",
  "who": "Who created this process and what application it belongs to.",
  "what": "What this process does and what it is currently doing.",
  "where": "Where the executable is located on disk. Note if the location is normal or unusual.",
  "allowed": "Whether this behaviour is expected and normal for this process type. Note anything unusual.",
  "path": "The full executable path exactly as provided. CRITICAL: You must escape all Windows backslashes (e.g. use C:\\\\Windows\\\\System32 instead of C:\\Windows\\System32)",
  "behaviour": "Two to five words summarising current behaviour. Example: Normal, low CPU usage"
}

Keep each field concise — one to two sentences maximum per field except
verdictReason which must be one sentence only. Write plainly so a
non-technical person can understand. Do not use markdown inside any field value.
CRITICAL: Ensure the output is valid JSON. All backslashes in paths must be double-escaped.''';

    final userMsg = '''
Process name: ${widget.process.name}
Command line arguments: ${widget.process.commandLine.isNotEmpty ? widget.process.commandLine : 'none'}
Parent process PID: ${widget.process.parentPid}
CPU usage: ${widget.process.cpuPercent}%
Memory: ${widget.process.memoryMb} MB
Status: ${widget.process.status}
Active network connections: ${conns.length}
Connection details:
$connText
''';

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final res = await dio.post<Map<String, dynamic>>(
        'https://api.groq.com/openai/v1/chat/completions',
        data: {
          "model": "llama-3.3-70b-versatile",
          "messages": [
            { "role": "system", "content": prompt },
            { "role": "user", "content": userMsg }
          ],
          "max_tokens": 400,
          "temperature": 0.3
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
        ),
      );

      final content = res.data?['choices']?[0]?['message']?['content'] as String?;
      if (content != null) {
        try {
          var cleanContent = content.trim();
          if (cleanContent.startsWith('```json')) {
            cleanContent = cleanContent.substring(7);
          } else if (cleanContent.startsWith('```')) {
            cleanContent = cleanContent.substring(3);
          }
          if (cleanContent.endsWith('```')) {
            cleanContent = cleanContent.substring(0, cleanContent.length - 3);
          }
          cleanContent = cleanContent.trim();
          
          // Fix common unescaped backslashes in Windows paths from LLMs
          cleanContent = cleanContent.replaceAllMapped(
            RegExp(r'\\([^"\\/bfnrtu])'),
            (m) => '\\\\${m.group(1)}',
          );

          final json = jsonDecode(cleanContent);
          final explanation = ProcessExplanation.fromJson(json);
          _explainCache[widget.pid] = ExplainResult(
            explanation: explanation,
            timestamp: DateTime.now(),
            isError: false,
          );
        } catch (e) {
          _explainCache[widget.pid] = ExplainResult(
            rawError: 'Analysis format error — showing raw response\n\n$content',
            timestamp: DateTime.now(),
            isError: true,
          );
        }
      } else {
        throw StateError('Invalid response format');
      }
    } on DioException catch (e) {
      String errStr = 'Request failed: ${e.message}';
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        errStr = 'Request timed out — check your internet connection';
      } else if (e.response != null) {
        if (e.response!.statusCode == 401) {
          errStr = 'Invalid Groq API key — check the key saved in Settings';
        } else if (e.response!.statusCode == 429) {
          errStr = 'Rate limit reached — try again in a moment';
          Future.delayed(const Duration(seconds: 8), () {
            if (mounted) _explain();
          });
        } else {
          errStr = '${e.response!.statusCode}: ${e.response!.statusMessage}';
        }
      }
      _explainCache[widget.pid] = ExplainResult(
        rawError: errStr,
        timestamp: DateTime.now(),
        isError: true,
      );
    } catch (e) {
      _explainCache[widget.pid] = ExplainResult(
        rawError: 'Error: $e',
        timestamp: DateTime.now(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Analysed just now';
    return 'Analysed ${diff.inMinutes} minutes ago';
  }

  Widget _buildVerdictBanner(ProcessExplanation exp, ColorScheme scheme) {
    Color bgColor;
    Color textColor;
    IconData icon;
    bool isMalicious = false;

    switch (exp.verdict.toLowerCase()) {
      case 'safe':
        bgColor = Colors.green.shade800;
        textColor = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case 'suspicious':
        bgColor = Colors.amber.shade700;
        textColor = Colors.black87;
        icon = Icons.warning_amber_rounded;
        break;
      case 'malicious':
        bgColor = Colors.red.shade800;
        textColor = Colors.white;
        icon = Icons.close_rounded;
        isMalicious = true;
        break;
      default:
        bgColor = Colors.grey.shade700;
        textColor = Colors.white;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isMalicious ? Border.all(color: Colors.redAccent, width: 2) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exp.verdict.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exp.verdictReason,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, IconData icon, String value, {Widget? extra}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 8),
                  extra,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final res = _explainCache[widget.pid];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _loading ? null : _explain,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.cyan,
            side: const BorderSide(color: Colors.cyan),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lightbulb_outline, size: 18),
          label: const Text('Explain Process'),
        ),
        if (res != null) ...[
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: EmDesign.cardShell(scheme).copyWith(
                border: res.explanation?.verdict.toLowerCase() == 'malicious'
                    ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(res.isError ? Icons.warning_amber_rounded : Icons.lightbulb_outline,
                          size: 16, color: res.isError ? Colors.amber : Colors.cyan),
                      const SizedBox(width: 8),
                      Text(
                        res.isError ? 'Error' : 'AI Analysis',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: res.isError ? Colors.amber : Colors.cyan,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(res.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _loading ? null : _explain,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Recheck', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (res.isError || res.explanation == null)
                    Text(
                      res.rawError ?? 'Unknown error',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: Colors.amber,
                          ),
                    )
                  else ...[
                    _buildVerdictBanner(res.explanation!, scheme),
                    const SizedBox(height: 20),
                    Text(
                      'PROCESS DETAILS',
                      style: EmDesign.labelCaps(context, scheme),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Who', Icons.person_outline, res.explanation!.who),
                    const Divider(height: 16),
                    _buildDetailRow('What', Icons.info_outline, res.explanation!.what),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Where',
                      Icons.location_on_outlined,
                      res.explanation!.where,
                      extra: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          res.explanation!.path,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11),
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.local_activity_outlined, size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Behaviour',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: res.explanation!.verdict.toLowerCase() == 'safe'
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : res.explanation!.verdict.toLowerCase() == 'suspicious'
                                              ? Colors.amber.withValues(alpha: 0.2)
                                              : res.explanation!.verdict.toLowerCase() == 'malicious'
                                                  ? Colors.red.withValues(alpha: 0.2)
                                                  : Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      res.explanation!.behaviour,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: res.explanation!.verdict.toLowerCase() == 'safe'
                                            ? Colors.green.shade700
                                            : res.explanation!.verdict.toLowerCase() == 'suspicious'
                                                ? Colors.amber.shade700
                                                : res.explanation!.verdict.toLowerCase() == 'malicious'
                                                    ? Colors.red.shade700
                                                    : scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Authorised Activity',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  res.explanation!.allowed,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: res.explanation!.verdict.toLowerCase() == 'suspicious'
                                        ? Colors.amber.shade700
                                        : res.explanation!.verdict.toLowerCase() == 'malicious'
                                            ? Colors.red.shade700
                                            : scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Powered by Groq · llama-3.3-70b-versatile\nAI analysis is a guide only — verify findings independently',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
        final theme = Theme.of(context);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = items[i];
            final contextLine = _sysmonEventContextLine(e);
            return Material(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(EmDesign.radiusSm),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sysmonEventTypeLabel(e.type),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatSysmonLocalTime(e.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (contextLine != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        contextLine,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          height: 1.35,
                          color: cs.primary.withValues(alpha: 0.88),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
