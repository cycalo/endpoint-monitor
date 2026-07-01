import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/connection_bloc.dart';
import '../bloc/process_bloc.dart';
import '../models/ws_models.dart';
import '../settings/app_settings_keys.dart';
import '../theme/em_design_system.dart';
import '../utils/em_snapshot_cache.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key, this.initialWatchFilter});

  /// Pre-fills search when opened from Watchlist (e.g. `notepad.exe`).
  final String? initialWatchFilter;

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

enum _Sort { name, cpu, memory, pid }

/// One row in the list: either a live process from the host or a post-kill ghost (stale PID).
class _ProcessViewRowData {
  const _ProcessViewRowData._({
    required this.snapshot,
    required this.isKilledGhost,
    this.killedAt,
  });

  factory _ProcessViewRowData.live(ProcessInfo p) =>
      _ProcessViewRowData._(snapshot: p, isKilledGhost: false);

  factory _ProcessViewRowData.killed(KilledProcessGhost g) =>
      _ProcessViewRowData._(
          snapshot: g.snapshot, isKilledGhost: true, killedAt: g.killedAt);

  final ProcessInfo snapshot;
  final bool isKilledGhost;
  final DateTime? killedAt;
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  _Sort _sort = _Sort.cpu;
  bool _compactCards = false;

  @override
  void initState() {
    super.initState();
    final w = widget.initialWatchFilter?.trim();
    if (w != null && w.isNotEmpty) {
      _search.text = w;
    }
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _compactCards = p.getBool(AppSettingsKeys.compactProcessCards) ?? false;
      });
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  void _openProcessDetail(BuildContext context, _ProcessViewRowData row) {
    // Drop focus before navigating so route pop does not restore the IME
    // for a still-focused search field (common after "minimize" keyboard).
    _searchFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    final p = row.snapshot;
    context.push(
      row.isKilledGhost
          ? '/processes/${p.pid}?ghost=1'
          : '/processes/${p.pid}',
    );
  }

  String _sortMenuLabel(_Sort s) {
    switch (s) {
      case _Sort.name:
        return 'Name';
      case _Sort.pid:
        return 'PID';
      case _Sort.cpu:
        return 'CPU usage';
      case _Sort.memory:
        return 'RAM usage';
    }
  }

  bool _matchesSearch(ProcessInfo p) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.name.toLowerCase().contains(q) ||
        p.pid.toString().contains(q) ||
        p.commandLine.toLowerCase().contains(q);
  }

  /// Live rows (sorted) then killed ghosts (newest first). Same executable respawning
  /// gets a new PID and appears only in the live list; ghosts are keyed by old PID.
  List<_ProcessViewRowData> _buildDisplayRows(ProcessState state) {
    var live = state.items.where(_matchesSearch).toList();
    switch (_sort) {
      case _Sort.name:
        live.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.cpu:
        live.sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));
      case _Sort.memory:
        live.sort((a, b) => b.memoryMb.compareTo(a.memoryMb));
      case _Sort.pid:
        live.sort((a, b) => a.pid.compareTo(b.pid));
    }
    final livePids = live.map((p) => p.pid).toSet();
    final ghosts = state.killedGhosts
        .where((g) => _matchesSearch(g.snapshot) && !livePids.contains(g.pid))
        .toList()
      ..sort((a, b) => b.killedAt.compareTo(a.killedAt));
    return [
      ...live.map(_ProcessViewRowData.live),
      ...ghosts.map(_ProcessViewRowData.killed),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        actions: [
          IconButton(
            tooltip: 'Alerts',
            onPressed: () => context.push('/alerts'),
            icon: Icon(Icons.visibility_rounded, color: scheme.primary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EmPageIntro(
                  title: 'Processes',
                  subtitle: 'Live and recently terminated processes on the endpoint.',
                  padding: EdgeInsets.zero,
                ),
                TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurface),
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchFocus.unfocus(),
                  onTapOutside: (_) => _searchFocus.unfocus(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: scheme.surfaceContainerLowest,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: scheme.outline, size: 22),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: Icon(Icons.clear_rounded,
                                color: scheme.outline, size: 20),
                          ),
                    hintText: 'Search processes by name, PID, or user...',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline.withValues(alpha: 0.7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                      borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                      borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                      borderSide: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('SORT', style: EmDesign.labelCaps(context, scheme)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<_Sort>(
                          tooltip: 'Sort',
                          offset: const Offset(0, 40),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _sortMenuLabel(_sort),
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.filter_list_rounded,
                                    size: 18, color: scheme.primary),
                              ],
                            ),
                          ),
                          onSelected: (v) => setState(() => _sort = v),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _Sort.name,
                              child: Text('Name',
                                  style: theme.textTheme.bodyMedium),
                            ),
                            PopupMenuItem(
                              value: _Sort.pid,
                              child: Text('PID',
                                  style: theme.textTheme.bodyMedium),
                            ),
                            PopupMenuItem(
                              value: _Sort.cpu,
                              child: Text('Resource usage (CPU)',
                                  style: theme.textTheme.bodyMedium),
                            ),
                            PopupMenuItem(
                              value: _Sort.memory,
                              child: Text('Resource usage (RAM)',
                                  style: theme.textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: scheme.surfaceContainerLow,
              child: BlocBuilder<ConnectionBloc, EmConnectionState>(
                builder: (context, conn) {
                  return BlocBuilder<ProcessBloc, ProcessState>(
                    builder: (context, state) {
                      Future<void> onRefresh() async {
                        if (!conn.isConnected) return;
                        context.read<ProcessBloc>().requestRefresh();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 900),
                        );
                      }

                      if (state.loading &&
                          state.items.isEmpty &&
                          state.killedGhosts.isEmpty) {
                        return const EmListSkeleton();
                      }

                      final rows = _buildDisplayRows(state);
                      if (rows.isEmpty) {
                        final hasSearch = _search.text.trim().isNotEmpty;
                        return EmEmptyState(
                          icon: hasSearch
                              ? Icons.search_off_rounded
                              : Icons.memory_outlined,
                          title: hasSearch
                              ? 'No matching processes'
                              : 'No processes yet',
                          message: hasSearch
                              ? 'Try a different name, PID, or command line.'
                              : conn.isConnected
                                  ? 'Waiting for the process list from the endpoint.'
                                  : 'Reconnect to refresh the process list.',
                        );
                      }

                      return RefreshIndicator(
                        color: scheme.primary,
                        onRefresh: onRefresh,
                        child: NotificationListener<ScrollStartNotification>(
                          onNotification: (n) {
                            if (n.dragDetails != null) {
                              _searchFocus.unfocus();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              0,
                              0,
                              EmDesign.scrollBottomInset,
                            ),
                            itemCount: rows.length +
                                (!conn.isConnected && state.items.isNotEmpty
                                    ? 1
                                    : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox.shrink(),
                            itemBuilder: (context, i) {
                              if (!conn.isConnected &&
                                  state.items.isNotEmpty &&
                                  i == 0) {
                                return FutureBuilder<DateTime?>(
                                  future:
                                      EmSnapshotCache.processesCachedAt(),
                                  builder: (context, snap) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        8,
                                        16,
                                        8,
                                      ),
                                      child: EmStaleSnapshotBanner(
                                        cachedAt: snap.data,
                                        compact: true,
                                      ),
                                    );
                                  },
                                );
                              }
                              final rowIndex = !conn.isConnected &&
                                      state.items.isNotEmpty
                                  ? i - 1
                                  : i;
                              final row = rows[rowIndex];
                              final p = row.snapshot;
                              return _ProcessRow(
                                key: ValueKey<String>(
                                  '${row.isKilledGhost ? 'g' : 'l'}-${p.pid}',
                                ),
                                p: p,
                                index: rowIndex,
                                isKilledGhost: row.isKilledGhost,
                                killedAt: row.killedAt,
                                compact: _compactCards,
                                onRowTap: () =>
                                    _openProcessDetail(context, row),
                                onDismissGhost: row.isKilledGhost
                                    ? () => context
                                        .read<ProcessBloc>()
                                        .dismissKilledGhost(p.pid)
                                    : null,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessCategory {
  const _ProcessCategory({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  static _ProcessCategory forName(String name, ColorScheme scheme) {
    final n = name.toLowerCase();
    if (n.contains('chrome') ||
        n.contains('msedge') ||
        n.contains('firefox') ||
        n.contains('browser')) {
      return _ProcessCategory(
        icon: Icons.travel_explore_rounded,
        background: scheme.surfaceContainerHighest,
        foreground: scheme.primary,
      );
    }
    if (n.contains('msmp') ||
        n.contains('defender') ||
        n.contains('smartscreen') ||
        n.contains('securityhealth')) {
      return _ProcessCategory(
        icon: Icons.security_rounded,
        background: scheme.errorContainer.withValues(alpha: 0.2),
        foreground: scheme.error,
      );
    }
    if (n.contains('code') || n.contains('devenv') || n.contains('vscode')) {
      return _ProcessCategory(
        icon: Icons.terminal_rounded,
        background: scheme.surfaceContainerHighest,
        foreground: scheme.primary,
      );
    }
    if (n.contains('svchost') ||
        n.contains('system') ||
        n.contains('service') ||
        n.contains('host')) {
      return _ProcessCategory(
        icon: Icons.settings_suggest_rounded,
        background: scheme.surfaceContainerHighest,
        foreground: scheme.tertiary,
      );
    }
    return _ProcessCategory(
      icon: Icons.memory_rounded,
      background: scheme.surfaceContainerHighest,
      foreground: scheme.primary,
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    super.key,
    required this.p,
    required this.index,
    required this.isKilledGhost,
    this.killedAt,
    this.compact = false,
    required this.onRowTap,
    this.onDismissGhost,
  });

  final ProcessInfo p;
  final int index;
  final bool isKilledGhost;
  final DateTime? killedAt;
  final bool compact;
  final VoidCallback onRowTap;
  final VoidCallback? onDismissGhost;

  static const _highCpuWarn = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cat = _ProcessCategory.forName(p.name, scheme);
    final suspended = !isKilledGhost &&
        context.select<ProcessBloc, bool>(
          (bloc) =>
              bloc.state.suspendedPids.contains(p.pid) ||
              p.status.toLowerCase().contains('suspend'),
        );
    final highCpu = !isKilledGhost && p.cpuPercent > _highCpuWarn;

    final rowBg = isKilledGhost
        ? scheme.errorContainer.withValues(alpha: 0.12)
        : (index.isEven ? scheme.surface : scheme.surfaceContainerLow);

    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 14,
      color: scheme.onSurface,
    );

    final pidChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'PID: ${p.pid}',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: scheme.secondary,
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowBg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, compact ? 8 : 16, 12, compact ? 8 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onRowTap,
                      hoverColor:
                          scheme.surfaceContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cat.background,
                              borderRadius:
                                  BorderRadius.circular(EmDesign.radiusMd),
                            ),
                            child:
                                Icon(cat.icon, color: cat.foreground, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: suspended
                                        ? nameStyle?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: scheme.outline,
                                          )
                                        : (isKilledGhost
                                            ? nameStyle?.copyWith(
                                                color: scheme.onSurfaceVariant)
                                            : nameStyle),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                pidChip,
                                if (isKilledGhost) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: scheme.errorContainer
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'KILLED',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        color: scheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: scheme.outline, size: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isKilledGhost) ...[
                          Row(
                            children: [
                              Icon(Icons.memory_rounded,
                                  size: 14,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.65)),
                              const SizedBox(width: 4),
                              Text(
                                '${p.cpuPercent.toStringAsFixed(1)}% CPU',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.storage_rounded,
                                  size: 14,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.65)),
                              const SizedBox(width: 4),
                              Text(
                                '${p.memoryMb.toStringAsFixed(0)} MB RAM (snapshot)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ] else if (highCpu && !suspended) ...[
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 14, color: scheme.error),
                              const SizedBox(width: 4),
                              Text(
                                'High CPU usage',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.error,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.memory_rounded,
                                  size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${p.cpuPercent.toStringAsFixed(1)}% CPU',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.memory_rounded,
                                  size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${p.cpuPercent.toStringAsFixed(1)}% CPU',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: highCpu
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                  fontWeight: highCpu
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.storage_rounded,
                                  size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${p.memoryMb.toStringAsFixed(0)} MB RAM',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onDismissGhost != null)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, compact ? 8 : 12),
                child: OutlinedButton(
                  onPressed: onDismissGhost,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.45)),
                    backgroundColor:
                        scheme.errorContainer.withValues(alpha: 0.16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
