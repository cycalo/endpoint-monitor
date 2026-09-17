import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/threat_intel_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../utils/country_flag_emoji.dart';
import '../utils/ip_normalize.dart';
import '../utils/network_endpoint_display.dart';
import '../utils/network_process_groups.dart';
import '../utils/network_tcp_state.dart';

typedef NetworkIpBlockCallback = Future<void> Function(NetworkConnection socket);
typedef NetworkProcessBlockCallback = Future<void> Function(String processName);

class EmNetworkAppCard extends StatefulWidget {
  const EmNetworkAppCard({
    super.key,
    required this.group,
    required this.scheme,
    required this.blockedMap,
    required this.processBlocked,
    required this.processBlockDirection,
    required this.threatLookup,
    required this.rowIcon,
    required this.onBlockProcess,
    required this.onUnblockProcess,
    required this.onBlockIp,
    required this.onUnblockIp,
    this.initiallyExpanded = false,
    this.stripeIndex = 0,
  });

  final NetworkProcessGroup group;
  final ColorScheme scheme;
  final Map<String, BlockedRemoteMeta> blockedMap;
  final bool processBlocked;
  final String? processBlockDirection;
  final ThreatIntelEntry? Function(String ip) threatLookup;
  final IconData Function(String processName) rowIcon;
  final NetworkProcessBlockCallback onBlockProcess;
  final NetworkProcessBlockCallback onUnblockProcess;
  final NetworkIpBlockCallback onBlockIp;
  final NetworkIpBlockCallback onUnblockIp;
  final bool initiallyExpanded;
  final int stripeIndex;

  @override
  State<EmNetworkAppCard> createState() => _EmNetworkAppCardState();
}

class _EmNetworkAppCardState extends State<EmNetworkAppCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant EmNetworkAppCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _expanded = true;
    }
  }

  bool _ipBlocked(String remote) {
    final k = normalizeIpForBlockList(remote);
    return k.isNotEmpty && widget.blockedMap.containsKey(k);
  }

  bool get _hasThreat =>
      widget.group.remotes.any((r) => widget.threatLookup(
            normalizeIpForBlockList(r.remoteAddress),
          ) !=
          null);

  Color get _stripeColor {
    if (widget.processBlocked) return widget.scheme.error;
    if (_hasThreat) return widget.scheme.tertiary;
    if (widget.group.establishedCount > 0) {
      return networkStateColor(widget.scheme, 'ESTABLISHED');
    }
    return widget.scheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final g = widget.group;
    final bg = widget.stripeIndex.isEven
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLow;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: _stripeColor.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(EmDesign.radiusLg),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius:
                                BorderRadius.circular(EmDesign.radiusMd),
                          ),
                          child: Icon(
                            widget.rowIcon(g.processName),
                            color: scheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      g.processName,
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (widget.processBlocked)
                                    _chip('BLOCKED', scheme.error),
                                  if (_hasThreat && !widget.processBlocked)
                                    _chip('THREAT IP', scheme.tertiary),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                g.pidCount <= 1
                                    ? '1 process'
                                    : '${g.pidCount} processes',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (g.summaryLine.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  g.summaryLine,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: widget.processBlocked
                              ? () => widget.onUnblockProcess(g.processName)
                              : () => widget.onBlockProcess(g.processName),
                          borderRadius:
                              BorderRadius.circular(EmDesign.radiusSm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: widget.processBlocked
                                  ? scheme.primaryContainer
                                      .withValues(alpha: 0.65)
                                  : scheme.errorContainer,
                              borderRadius:
                                  BorderRadius.circular(EmDesign.radiusSm),
                            ),
                            child: Text(
                              widget.processBlocked
                                  ? 'Unblock app'
                                  : 'Block app',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: widget.processBlocked
                                    ? scheme.primary
                                    : scheme.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 12),
                    if (g.remotes.isNotEmpty) ...[
                      Text(
                        'Remote peers',
                        style: EmDesign.labelCaps(context, scheme),
                      ),
                      const SizedBox(height: 8),
                      for (final remote in g.remotes)
                        _RemoteRollupTile(
                          rollup: remote,
                          scheme: scheme,
                          blocked: _ipBlocked(remote.remoteAddress),
                          threat: widget.threatLookup(
                            normalizeIpForBlockList(remote.remoteAddress),
                          ),
                          onOpenDetail: () => context.push(
                            '/network/detail',
                            extra: remote.representative,
                          ),
                          onBlock: () =>
                              widget.onBlockIp(remote.representative),
                          onUnblock: () =>
                              widget.onUnblockIp(remote.representative),
                        ),
                    ],
                    if (g.localBinds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(
                            'Local binds (${g.localBinds.length})',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          children: [
                            for (final bind in g.localBinds)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${bind.protocol.toUpperCase()} ${normalizeCimTcpState(bind.state).isEmpty ? 'LOCAL' : normalizeCimTcpState(bind.state)} · ${formatNetworkEndpoint(bind.localAddress, bind.localPort)}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Listen only',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _RemoteRollupTile extends StatelessWidget {
  const _RemoteRollupTile({
    required this.rollup,
    required this.scheme,
    required this.blocked,
    required this.threat,
    required this.onOpenDetail,
    required this.onBlock,
    required this.onUnblock,
  });

  final NetworkRemoteRollup rollup;
  final ColorScheme scheme;
  final bool blocked;
  final ThreatIntelEntry? threat;
  final VoidCallback onOpenDetail;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final sample = rollup.geoSample;
    final cc = sample?.countryCode ?? '';
    final city = sample?.city ?? '';
    final country = sample?.countryName ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(EmDesign.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (countryCodeToFlagEmoji(cc).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 1),
                    child: Text(
                      countryCodeToFlagEmoji(cc),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatNetworkEndpoint(
                          rollup.remoteAddress,
                          rollup.remotePort,
                        ),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.tertiary,
                        ),
                      ),
                      if (city.isNotEmpty || country.isNotEmpty)
                        Text(
                          city.isNotEmpty ? city : country,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (rollup.socketCount > 1)
                        Text(
                          '×${rollup.socketCount} sockets',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: scheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                if (blocked)
                  Text(
                    'BLOCKED',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: scheme.error,
                    ),
                  )
                else if (threat != null)
                  Text(
                    'THREAT',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: scheme.tertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenDetail,
                    child: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: blocked
                          ? scheme.primaryContainer
                          : scheme.errorContainer,
                      foregroundColor:
                          blocked ? scheme.primary : scheme.error,
                    ),
                    onPressed: blocked ? onUnblock : onBlock,
                    child: Text(blocked ? 'Unblock IP' : 'Block IP'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
