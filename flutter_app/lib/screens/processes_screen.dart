import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/process_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

enum _Sort { name, cpu, memory, pid }

class _ProcessesScreenState extends State<ProcessesScreen> {
  final _search = TextEditingController();
  _Sort _sort = _Sort.cpu;
  int? _expandedPid;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = GoogleFonts.jetBrainsMono(color: scheme.onSurfaceVariant, fontSize: 11);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'System processes',
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: -0.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                    border: EmDesign.ghostBorder(scheme),
                  ),
                  child: TextField(
                    controller: _search,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      hintText: 'Search by name, PID, or user…',
                      hintStyle: mono.copyWith(
                        color: scheme.outline.withValues(alpha: 0.45),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: scheme.outline, size: 22),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: Icon(Icons.clear_rounded, color: scheme.outline, size: 22),
                            ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: SegmentedButton<_Sort>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _Sort.cpu,
                          label: Text('CPU', style: TextStyle(fontSize: 10)),
                        ),
                        ButtonSegment(
                          value: _Sort.memory,
                          label: Text('RAM', style: TextStyle(fontSize: 10)),
                        ),
                        ButtonSegment(
                          value: _Sort.name,
                          label: Text('NAME', style: TextStyle(fontSize: 10)),
                        ),
                        ButtonSegment(
                          value: _Sort.pid,
                          label: Text('PID', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                      selected: {_sort},
                      onSelectionChanged: (s) => setState(() => _sort = s.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      'PROCESS NAME',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: scheme.outlineVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      'PID',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: scheme.outlineVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CPU',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: scheme.outlineVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'MEMORY',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: scheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<ProcessBloc, ProcessState>(
              builder: (context, state) {
                if (state.loading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                var list = state.items.where((p) {
                  final q = _search.text.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return p.name.toLowerCase().contains(q) || p.pid.toString().contains(q);
                }).toList();
                switch (_sort) {
                  case _Sort.name:
                    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  case _Sort.cpu:
                    list.sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));
                  case _Sort.memory:
                    list.sort((a, b) => b.memoryMb.compareTo(a.memoryMb));
                  case _Sort.pid:
                    list.sort((a, b) => a.pid.compareTo(b.pid));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    final expanded = _expandedPid == p.pid;
                    return _ProcessRow(
                      p: p,
                      index: i,
                      expanded: expanded,
                      mono: mono,
                      onToggle: () => setState(() {
                        _expandedPid = expanded ? null : p.pid;
                      }),
                      onOpenDetail: () => context.push('/processes/${p.pid}'),
                      onKill: () => _confirmKill(context, p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmKill(BuildContext context, ProcessInfo p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kill process?'),
        content: Text('${p.name} (${p.pid})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kill')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ProcessBloc>().sendCommand({'type': 'kill_process', 'pid': p.pid});
    }
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.p,
    required this.index,
    required this.expanded,
    required this.mono,
    required this.onToggle,
    required this.onOpenDetail,
    required this.onKill,
  });

  final ProcessInfo p;
  final int index;
  final bool expanded;
  final TextStyle mono;
  final VoidCallback onToggle;
  final VoidCallback onOpenDetail;
  final VoidCallback onKill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hotCpu = p.cpuPercent > 50;
    final hotMem = p.memoryMb > 500;
    final accent = hotCpu || hotMem ? scheme.primary : scheme.tertiary;
    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: hotCpu || hotMem ? scheme.primary : scheme.onSurface,
    );
    final suspended = p.status.toLowerCase().contains('suspend');

    final zebra = index.isEven ? scheme.surface : scheme.surfaceContainerLowest;
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: expanded ? scheme.surfaceContainerHigh : zebra,
          borderRadius: BorderRadius.circular(EmDesign.radiusSm),
          // Never use width:0 with borderRadius — Flutter asserts (hairline rule).
          border: expanded || hotCpu
              ? Border(
                  left: BorderSide(
                    color: expanded
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.7),
                    width: 2,
                  ),
                )
              : null,
          boxShadow: expanded
              ? [
                  BoxShadow(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(EmDesign.radiusSm),
          hoverColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: suspended ? scheme.outline : accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: suspended
                            ? nameStyle?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: scheme.outline,
                              )
                            : nameStyle,
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${p.pid}',
                        style: mono.copyWith(
                          color: hotCpu ? scheme.primary : scheme.outline,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${p.cpuPercent.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: mono.copyWith(
                          color: hotCpu ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${p.memoryMb.toStringAsFixed(0)} MB',
                        textAlign: TextAlign.right,
                        style: mono.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    Icon(
                      suspended
                          ? Icons.pause_circle_outline_rounded
                          : hotCpu
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                      color: suspended
                          ? Colors.orange.shade400
                          : hotCpu
                              ? scheme.primary
                              : scheme.tertiary,
                      size: 22,
                    ),
                  ],
                ),
              ),
              if (expanded) ...[
                Container(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.1),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Executable / command',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        p.commandLine.isEmpty ? '(no command line)' : p.commandLine,
                        style: mono.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PARENT PID', style: theme.textTheme.labelSmall),
                                Text('${p.parentPid}', style: mono.copyWith(fontSize: 13)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('STATUS', style: theme.textTheme.labelSmall),
                                Text(p.status, style: mono.copyWith(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: onOpenDetail,
                        child: const Text('Open full detail'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.read<ProcessBloc>().sendCommand({
                              'type': 'flag_process',
                              'name': p.name,
                            }),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const Text('Flag'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.read<ProcessBloc>().sendCommand({
                              'type': 'suspend_process',
                              'pid': p.pid,
                            }),
                            icon: const Icon(Icons.pause_rounded, size: 18),
                            label: const Text('Suspend'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.read<ProcessBloc>().sendCommand({
                              'type': 'resume_process',
                              'pid': p.pid,
                            }),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Resume'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.errorContainer,
                              foregroundColor: scheme.onErrorContainer,
                            ),
                            onPressed: onKill,
                            icon: const Icon(Icons.dangerous_outlined, size: 18),
                            label: const Text('Kill'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
