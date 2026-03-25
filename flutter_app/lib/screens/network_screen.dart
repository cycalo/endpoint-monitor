import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/network_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _search = TextEditingController();
  String _protocol = 'all';
  String _state = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = GoogleFonts.jetBrainsMono(fontSize: 12, color: scheme.onSurfaceVariant);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Network monitor',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _protocol,
                    decoration: const InputDecoration(labelText: 'Protocol'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'TCP', child: Text('TCP')),
                      DropdownMenuItem(value: 'UDP', child: Text('UDP')),
                    ],
                    onChanged: (v) => setState(() => _protocol = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _state,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'ESTABLISHED', child: Text('ESTABLISHED')),
                      DropdownMenuItem(value: 'LISTEN', child: Text('LISTEN')),
                      DropdownMenuItem(value: 'TIME_WAIT', child: Text('TIME_WAIT')),
                    ],
                    onChanged: (v) => setState(() => _state = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                border: EmDesign.ghostBorder(scheme),
              ),
              child: TextField(
                controller: _search,
                style: mono,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded, color: scheme.outline),
                  hintText: 'Search IP or process',
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
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<NetworkBloc, NetworkState>(
              builder: (context, state) {
                if (state.loading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final q = _search.text.trim().toLowerCase();
                final list = state.items.where((n) {
                  if (_protocol != 'all' && n.protocol != _protocol) return false;
                  if (_state != 'all' && n.state != _state && n.protocol == 'TCP') {
                    return false;
                  }
                  if (q.isEmpty) return true;
                  return n.remoteAddress.toLowerCase().contains(q) ||
                      n.processName.toLowerCase().contains(q);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active connections',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${list.length} active',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                'No matching connections',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final n = list[i];
                                return Material(
                                  color: scheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                      border: EmDesign.ghostBorder(scheme),
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                      ),
                                      collapsedShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                      ),
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                                        ),
                                        child: Icon(
                                          Icons.public_rounded,
                                          color: scheme.primary,
                                        ),
                                      ),
                                      title: Text(
                                        '${n.processName} (${n.pid})',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${n.localAddress}:${n.localPort} → ${n.remoteAddress}:${n.remotePort} · ${n.protocol} ${n.state}',
                                          style: mono.copyWith(fontSize: 11),
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                          child: Row(
                                            children: [
                                              TextButton(
                                                onPressed: n.remoteAddress.isEmpty
                                                    ? null
                                                    : () => _block(context, n),
                                                child: const Text('Block IP'),
                                              ),
                                              TextButton(
                                                onPressed: n.remoteAddress.isEmpty
                                                    ? null
                                                    : () => context.read<NetworkBloc>().sendCommand({
                                                          'type': 'unblock_ip',
                                                          'ip': n.remoteAddress,
                                                        }),
                                                child: const Text('Unblock'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _block(BuildContext context, NetworkConnection n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Block remote IP?'),
        content: Text(n.remoteAddress),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Block')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<NetworkBloc>().sendCommand({
        'type': 'block_ip',
        'ip': n.remoteAddress,
        'direction': 'outbound',
      });
    }
  }
}
