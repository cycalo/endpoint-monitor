import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/network_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../utils/country_flag_emoji.dart';
import '../widgets/em_brand_app_bar.dart';

class NetworkConnectionDetailScreen extends StatelessWidget {
  const NetworkConnectionDetailScreen({super.key, required this.connection});

  final NetworkConnection connection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: BlocBuilder<NetworkBloc, NetworkState>(
        builder: (context, netState) {
          final current = _resolveCurrentConnection(netState.items, connection);
          final related = netState.items
              .where((n) => n.pid == current.pid && !_isListeningSocket(n))
              .toList()
            ..sort((a, b) {
              final c = a.remoteAddress.compareTo(b.remoteAddress);
              if (c != 0) return c;
              return a.remotePort.compareTo(b.remotePort);
            });

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Header(connection: current),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'CONNECTION DETAILS',
                      icon: Icons.cable_rounded,
                      child: Column(
                        children: [
                          _kvRow('Remote endpoint', _endpoint(current.remoteAddress, current.remotePort)),
                          _kvRow('Local endpoint', _endpoint(current.localAddress, current.localPort)),
                          _kvRow('Protocol / State', _protocolState(current.protocol, current.state)),
                          _kvRow('Duration', _connectionDuration(current)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'OWNERSHIP',
                      icon: Icons.public_rounded,
                      child: _buildOwnershipContent(context, current),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'ALL CONNECTIONS (THIS PROCESS)',
                      icon: Icons.hub_rounded,
                      child: related.isEmpty
                          ? Text(
                              'No active remote connections for this process in the latest snapshot.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < related.length; i++) ...[
                                  _RelatedConnectionRow(item: related[i]),
                                  if (i != related.length - 1)
                                    Divider(
                                      height: 16,
                                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'ACTIONS',
                      icon: Icons.shield_rounded,
                      child: current.remoteAddress.isEmpty
                          ? Text(
                              'No remote IP available for this connection.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _confirmNetworkBlock(context, current),
                                    child: const Text('Block IP'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: () => context.read<NetworkBloc>().sendCommand({
                                      'type': 'unblock_ip',
                                      'ip': current.remoteAddress,
                                    }),
                                    child: const Text('Unblock IP'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.connection});

  final NetworkConnection connection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: scheme.primary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connection.processName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _endpoint(connection.remoteAddress, connection.remotePort),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: EmDesign.labelCaps(context, scheme),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RelatedConnectionRow extends StatelessWidget {
  const _RelatedConnectionRow({required this.item});

  final NetworkConnection item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _endpoint(item.remoteAddress, item.remotePort),
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'Local ${_endpoint(item.localAddress, item.localPort)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _protocolState(item.protocol, item.state),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.tertiary,
          ),
        ),
      ],
    );
  }
}

Widget _buildOwnershipContent(BuildContext context, NetworkConnection c) {
  final hasOrg = c.org.trim().isNotEmpty;
  final hasCountry = c.countryName.trim().isNotEmpty || c.countryCode.trim().isNotEmpty;
  final hasCity = c.city.trim().isNotEmpty;
  final hasAny = hasOrg || hasCountry || hasCity;
  if (!hasAny) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      'No public ownership/geolocation data for this endpoint yet.',
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  final rows = <Widget>[
    if (hasOrg) _kvRow('Organisation', c.org.trim()),
    if (hasCountry) _kvRow('Country', _countryLine(c)),
    if (hasCity) _kvRow('City', c.city.trim()),
  ];
  return Column(children: rows);
}

Widget _kvRow(String label, String value) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _endpoint(String address, int port) {
  if (address.trim().isEmpty) return '—';
  if (port <= 0) return address;
  return '$address:$port';
}

NetworkConnection _resolveCurrentConnection(
  List<NetworkConnection> items,
  NetworkConnection fallback,
) {
  for (final n in items) {
    if (_connectionStableKey(n) == _connectionStableKey(fallback)) {
      return n;
    }
  }
  return fallback;
}

String _connectionStableKey(NetworkConnection c) {
  return '${c.pid}|${c.localAddress}|${c.localPort}|${c.remoteAddress}|${c.remotePort}|${c.protocol}';
}

String _connectionDuration(NetworkConnection c) {
  if (c.durationSeconds > 0) {
    return _formatDurationSeconds(c.durationSeconds);
  }
  if (c.protocol.toUpperCase() == 'TCP' && _readableState(c.state).toUpperCase() == 'ESTABLISHED') {
    return '< 1s';
  }
  return 'Unavailable in current snapshot';
}

String _formatDurationSeconds(int totalSeconds) {
  if (totalSeconds < 60) return '${totalSeconds}s';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes < 60) return '${minutes}m ${seconds}s';
  final hours = minutes ~/ 60;
  final remMinutes = minutes % 60;
  if (hours < 24) return '${hours}h ${remMinutes}m';
  final days = hours ~/ 24;
  final remHours = hours % 24;
  return '${days}d ${remHours}h';
}

String _protocolState(String protocol, String state) {
  final p = protocol.trim().isEmpty ? 'UNKNOWN' : protocol.trim().toUpperCase();
  final s = _readableState(state);
  return '$p · $s';
}

String _readableState(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return 'UNKNOWN';
  final n = int.tryParse(v);
  if (n == null) return v.toUpperCase();
  switch (n) {
    case 1:
      return 'CLOSED';
    case 2:
      return 'LISTEN';
    case 3:
      return 'SYN-SENT';
    case 4:
      return 'SYN-RECEIVED';
    case 5:
      return 'ESTABLISHED';
    case 6:
      return 'FIN-WAIT-1';
    case 7:
      return 'FIN-WAIT-2';
    case 8:
      return 'CLOSE-WAIT';
    case 9:
      return 'CLOSING';
    case 10:
      return 'LAST-ACK';
    case 11:
      return 'TIME-WAIT';
    case 12:
      return 'DELETE-TCB';
    default:
      return 'STATE-$n';
  }
}

bool _isListeningSocket(NetworkConnection n) {
  final r = n.remoteAddress.trim();
  final state = _readableState(n.state);
  if (state == 'LISTEN') return true;
  if (n.remotePort == 0) return true;
  if (r.isEmpty || r == '0.0.0.0' || r == '::' || r == '*') return true;
  return false;
}

String _countryLine(NetworkConnection c) {
  final flag = countryCodeToFlagEmoji(c.countryCode);
  final text = c.countryName.isNotEmpty
      ? c.countryName
      : (c.countryCode.isNotEmpty ? c.countryCode : 'Unknown');
  return flag.isEmpty ? text : '$flag $text';
}

Future<void> _confirmNetworkBlock(BuildContext context, NetworkConnection n) async {
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
