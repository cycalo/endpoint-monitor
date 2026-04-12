import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/alerts_bloc.dart';
import '../bloc/process_bloc.dart';
import '../models/ws_models.dart';
import '../bloc/watchlist_bloc.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final _name = TextEditingController();
  bool _alertsOpen = true;

  static String _rel(DateTime? utc) {
    if (utc == null) return 'Never detected';
    final now = DateTime.now().toUtc();
    var d = now.difference(utc.toUtc());
    if (d.isNegative) d = Duration.zero;
    if (d.inMinutes < 1) return 'Last seen just now';
    if (d.inHours < 1) return 'Last seen ${d.inMinutes}m ago';
    if (d.inDays < 1) return 'Last seen ${d.inHours}h ago';
    if (d.inDays < 14) return 'Last seen ${d.inDays}d ago';
    return 'Last seen ${(d.inDays / 7).floor()}w ago';
  }

  static String _addedRel(DateTime? utc) {
    if (utc == null) return 'Added recently';
    final now = DateTime.now().toUtc();
    var d = now.difference(utc.toUtc());
    if (d.isNegative) d = Duration.zero;
    if (d.inDays < 1) return 'Added ${d.inHours}h ago';
    return 'Added ${d.inDays}d ago';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WatchlistBloc>().refreshFromServer();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// First live process whose name matches the watchlist entry (case-insensitive).
  /// Used for "running" UI and to open `/processes/:pid` directly.
  static ProcessInfo? _matchWatchlistProcess(
    String processName,
    List<ProcessInfo> processes,
  ) {
    final want = processName.toLowerCase();
    for (final p in processes) {
      if (p.name.toLowerCase() == want) return p;
    }
    return null;
  }

  Future<void> _confirmRemove(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove from watchlist?'),
        content: Text('Stop monitoring $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true && mounted) context.read<WatchlistBloc>().remove(name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: BlocBuilder<WatchlistBloc, WatchlistState>(
        builder: (context, wl) {
          final unackedFlagged = context.select<AlertsBloc, int>((b) {
            return b.state.items
                .where((a) => a.type == 'flagged_process' && !b.state.acked.contains(a.id))
                .length;
          });
          if (unackedFlagged > 0 && _alertsOpen == false) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _alertsOpen = true);
            });
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Text(
                'Watchlist',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Text('ADD PROCESS', style: EmDesign.labelCaps(context, scheme)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: EmDesign.cardShell(
                  scheme,
                  color: scheme.primaryContainer.withValues(alpha: 0.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      style: GoogleFonts.jetBrainsMono(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Process name e.g. malware.exe',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => context.read<WatchlistBloc>().clearAddError(),
                    ),
                    if (wl.addError != null) ...[
                      const SizedBox(height: 6),
                      Text(wl.addError!, style: TextStyle(color: scheme.error, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        context.read<WatchlistBloc>().addName(_name.text);
                        _name.clear();
                      },
                      child: const Text('Add to Watchlist'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'MONITORED PROCESSES (${wl.entries.length})',
                style: EmDesign.labelCaps(context, scheme),
              ),
              const SizedBox(height: 8),
              if (wl.serverListLoading && wl.entries.isEmpty)
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      height: 88,
                      decoration: EmDesign.cardShell(
                        scheme,
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                )
              else if (wl.entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: EmDesign.cardShell(scheme),
                  child: Column(
                    children: [
                      Icon(Icons.visibility_outlined, size: 40, color: scheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'No processes on watchlist — add a process name above to be alerted when it starts',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                      ),
                    ],
                  ),
                )
              else
                BlocBuilder<ProcessBloc, ProcessState>(
                  builder: (context, ps) {
                    return Column(
                      children: wl.entries.map((e) {
                        final match = _matchWatchlistProcess(e.name, ps.items);
                        final running = match != null;
                        final loadingSeen = wl.lastSeenLoadingNames.contains(e.name);
                        final seen = wl.lastSeenByName[e.name];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: EmDesign.cardShell(scheme).copyWith(
                              border: Border(
                                left: BorderSide(
                                  color: running ? scheme.tertiary : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.name,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _confirmRemove(e.name),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _addedRel(e.addedAt),
                                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (running)
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: scheme.tertiary,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: scheme.tertiary.withValues(alpha: 0.5),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Running now',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: scheme.tertiary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: scheme.outline,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Not currently active',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (loadingSeen)
                                    Text('Resolving last seen…', style: theme.textTheme.bodySmall)
                                  else
                                    Text(
                                      _rel(seen),
                                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                  if (match != null) ...[
                                    const SizedBox(height: 10),
                                    OutlinedButton(
                                      // `go` (not `push`): pushing from /watchlist into the shell's
                                      // nested /processes/:pid duplicates Navigator page keys.
                                      onPressed: () =>
                                          context.go('/processes/${match.pid}'),
                                      child: const Text('View Process'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 20),
              _RecentAlertsCard(
                expanded: _alertsOpen,
                onExpansionChanged: (o) => setState(() => _alertsOpen = o),
                unackedCount: unackedFlagged,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: EmDesign.cardShell(
                  scheme,
                  color: scheme.surfaceContainerLowest.withValues(alpha: 0.5),
                ),
                child: Text(
                  'Watchlisted processes generate a high severity alert and push notification when detected starting. '
                  'Monitoring is performed by the Windows service via Sysmon event analysis.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentAlertsCard extends StatelessWidget {
  const _RecentAlertsCard({
    required this.expanded,
    required this.onExpansionChanged,
    required this.unackedCount,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final int unackedCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return BlocBuilder<AlertsBloc, AlertsState>(
      builder: (context, alerts) {
        final flagged = alerts.items.where((a) => a.type == 'flagged_process').take(5).toList();
        return Container(
          decoration: EmDesign.cardShell(scheme),
          child: ExpansionTile(
            initiallyExpanded: expanded,
            onExpansionChanged: onExpansionChanged,
            leading: Icon(Icons.notifications_active_outlined, color: scheme.primary),
            title: Text(
              'Recent Alerts (${unackedCount > 0 ? unackedCount : flagged.length})',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            children: [
              if (flagged.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No watchlist alerts yet',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                ...flagged.map(
                  (a) => ListTile(
                    dense: true,
                    title: Text(a.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${a.severity} · ${a.timestamp}'),
                    trailing: TextButton(
                      onPressed: () => context.go('/alerts?type=flagged_process'),
                      child: const Text('View in Alerts'),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: OutlinedButton(
                  onPressed: () => context.go('/alerts?type=flagged_process'),
                  child: const Text('View all alerts'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
