import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/network_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../utils/country_flag_emoji.dart';
import '../utils/throughput_format.dart';
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
  String _geo = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static IconData _rowIcon(String processName) {
    final n = processName.toLowerCase();
    if (n.contains('chrome') || n.contains('msedge') || n.contains('firefox')) {
      return Icons.public_rounded;
    }
    if (n.contains('discord')) return Icons.forum_rounded;
    if (n.contains('spotify')) return Icons.music_note_rounded;
    if (n.contains('system') || n.contains('svchost')) return Icons.settings_rounded;
    return Icons.hub_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BlocBuilder<NetworkBloc, NetworkState>(
              builder: (context, state) {
                if (state.loading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _search.text.trim().toLowerCase();
                var list = state.items.where((n) {
                  if (_protocol != 'all' && n.protocol != _protocol) return false;
                  final normalizedState = _normalizeStateForFilter(n.state);
                  if (_state != 'all' && normalizedState != _state && n.protocol.toUpperCase() == 'TCP') {
                    return false;
                  }
                  if (_geo != 'all' && !_matchesGeoFilter(n, _geo)) {
                    return false;
                  }
                  if (q.isEmpty) return true;
                  return n.remoteAddress.toLowerCase().contains(q) ||
                      n.processName.toLowerCase().contains(q) ||
                      n.localAddress.toLowerCase().contains(q) ||
                      '${n.localPort}'.contains(q) ||
                      '${n.remotePort}'.contains(q) ||
                      n.city.toLowerCase().contains(q) ||
                      n.countryName.toLowerCase().contains(q) ||
                      n.countryCode.toLowerCase().contains(q) ||
                      n.org.toLowerCase().contains(q);
                }).toList();

                list.sort((a, b) => b.remoteAddress.compareTo(a.remoteAddress));

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: BlocBuilder<SystemInfoBloc, SystemInfoState>(
                          builder: (context, si) {
                            final uptime = si.info?.uptime.trim().isEmpty ?? true
                                ? '—'
                                : si.info!.uptime.trim();
                            final upMbps = formatMbpsFromBytesPerSec(si.info?.networkBytesSentPerSec ?? 0);
                            final downMbps = formatMbpsFromBytesPerSec(si.info?.networkBytesReceivedPerSec ?? 0);
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.speed_rounded, color: scheme.primary, size: 26),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SYSTEM NETWORK',
                                          style: EmDesign.labelCaps(context, scheme),
                                        ),
                                        const SizedBox(height: 4),
                                        Text.rich(
                                          TextSpan(
                                            style: GoogleFonts.manrope(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: scheme.onSurface,
                                            ),
                                            children: [
                                              TextSpan(text: upMbps),
                                              TextSpan(
                                                text: ' Mbps ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'UP',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                              const TextSpan(text: ' / '),
                                              TextSpan(text: downMbps),
                                              TextSpan(
                                                text: ' Mbps ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'DOWN',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: scheme.tertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'System-wide (all adapters)',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: scheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Uptime: $uptime',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _search,
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: scheme.surfaceContainer,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                                prefixIcon: Icon(Icons.search_rounded, color: scheme.outline),
                                hintText: 'Search process names or IP addresses',
                                hintStyle: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.outline.withValues(alpha: 0.7),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                  borderSide: BorderSide.none,
                                ),
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
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _FilterDropdown(
                                  label: 'Protocol',
                                  value: _protocol,
                                  items: const [
                                    _Fv('all', 'All protocols'),
                                    _Fv('TCP', 'TCP'),
                                    _Fv('UDP', 'UDP'),
                                  ],
                                  onChanged: (v) => setState(() => _protocol = v ?? 'all'),
                                ),
                                _FilterDropdown(
                                  label: 'State',
                                  value: _state,
                                  items: const [
                                    _Fv('all', 'All states'),
                                    _Fv('ESTABLISHED', 'Established'),
                                    _Fv('LISTEN', 'Listening'),
                                    _Fv('TIME_WAIT', 'Time wait'),
                                  ],
                                  onChanged: (v) => setState(() => _state = v ?? 'all'),
                                ),
                                _FilterDropdown(
                                  label: 'Geolocation',
                                  value: _geo,
                                  items: const [
                                    _Fv('all', 'Global'),
                                    _Fv('na', 'North America'),
                                    _Fv('eu', 'Europe'),
                                    _Fv('as', 'Asia'),
                                  ],
                                  onChanged: (v) => setState(() => _geo = v ?? 'all'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Text(
                              'Active connections',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_downward_rounded, size: 18, color: scheme.primary),
                            Icon(Icons.bar_chart_rounded, size: 18, color: scheme.primary),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: scheme.tertiary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${list.length} active',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (list.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No matching connections',
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final n = list[i];
                              final canBlock = n.remoteAddress.isNotEmpty;
                              final bg = i.isEven ? scheme.surfaceContainer : scheme.surfaceContainerLow;
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
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 3,
                                            decoration: BoxDecoration(
                                              color: scheme.primary,
                                              borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(EmDesign.radiusLg),
                                                bottom: Radius.circular(EmDesign.radiusLg),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 42,
                                                    height: 42,
                                                    decoration: BoxDecoration(
                                                      color: scheme.surfaceContainerLow,
                                                      borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                                    ),
                                                    child: Icon(
                                                      _rowIcon(n.processName),
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
                                                              child: Row(
                                                                children: [
                                                                  Flexible(
                                                                    child: Text(
                                                                      n.processName,
                                                                      style: GoogleFonts.manrope(
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.w800,
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal: 6,
                                                                      vertical: 2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: scheme.surfaceContainerHighest,
                                                                      borderRadius: BorderRadius.circular(4),
                                                                    ),
                                                                    child: Text(
                                                                      'PID: ${n.pid}',
                                                                      style: GoogleFonts.inter(
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.w700,
                                                                        color: scheme.onSurfaceVariant,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Builder(
                                                              builder: (context) {
                                                                final state = _normalizeStateForFilter(n.state);
                                                                final stateColor = _stateColor(scheme, state);
                                                                return Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Container(
                                                                  width: 8,
                                                                  height: 8,
                                                                  decoration: BoxDecoration(
                                                                    shape: BoxShape.circle,
                                                                    color: stateColor,
                                                                    boxShadow: state == 'LISTEN'
                                                                        ? null
                                                                        : [
                                                                            BoxShadow(
                                                                              color: stateColor.withValues(alpha: 0.7),
                                                                              blurRadius: 8,
                                                                            ),
                                                                          ],
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 6),
                                                                Text(
                                                                  '${n.protocol.toUpperCase()}  $state',
                                                                  style: GoogleFonts.inter(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w800,
                                                                    letterSpacing: 0.45,
                                                                    color: stateColor,
                                                                  ),
                                                                ),
                                                              ],
                                                            );
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text.rich(
                                                          TextSpan(
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11.5,
                                                              color: scheme.onSurfaceVariant,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            children: [
                                                              const TextSpan(text: 'Local: '),
                                                              TextSpan(
                                                                text: '${n.localAddress}:${n.localPort}',
                                                                style: TextStyle(color: scheme.onSurface),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text.rich(
                                                          TextSpan(
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11.5,
                                                              color: scheme.onSurfaceVariant,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            children: [
                                                              const TextSpan(text: 'Remote: '),
                                                              TextSpan(
                                                                text: n.remoteAddress.isEmpty
                                                                    ? '—'
                                                                    : '${n.remoteAddress}:${n.remotePort}',
                                                                style: TextStyle(
                                                                  color: scheme.tertiary,
                                                                  fontWeight: FontWeight.w700,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (n.city.isNotEmpty ||
                                                            n.countryName.isNotEmpty ||
                                                            n.countryCode.isNotEmpty) ...[
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            children: [
                                                              if (countryCodeToFlagEmoji(n.countryCode).isNotEmpty)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(right: 6),
                                                                  child: Text(
                                                                    countryCodeToFlagEmoji(n.countryCode),
                                                                    style: const TextStyle(fontSize: 16),
                                                                  ),
                                                                ),
                                                              Expanded(
                                                                child: Text(
                                                                  n.city.isNotEmpty
                                                                      ? n.city
                                                                      : (n.countryName.isNotEmpty
                                                                          ? n.countryName
                                                                          : n.countryCode),
                                                                  style: GoogleFonts.inter(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: scheme.onSurface,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
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
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: InkWell(
                                                      onTap: () => context.push(
                                                        '/network/detail',
                                                        extra: n,
                                                      ),
                                                      borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                                        alignment: Alignment.center,
                                                        decoration: BoxDecoration(
                                                          color: scheme.surfaceContainerHighest,
                                                          borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                                                        ),
                                                        child: Text(
                                                          'Details',
                                                          style: GoogleFonts.manrope(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: InkWell(
                                                      onTap: canBlock
                                                          ? () => _block(context, n)
                                                          : null,
                                                      borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                                        alignment: Alignment.center,
                                                        decoration: BoxDecoration(
                                                          color: canBlock
                                                              ? scheme.errorContainer
                                                              : scheme.surfaceContainerHighest
                                                                  .withValues(alpha: 0.45),
                                                          borderRadius: BorderRadius.circular(EmDesign.radiusSm),
                                                        ),
                                                        child: Text(
                                                          'Block connection',
                                                          style: GoogleFonts.manrope(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w800,
                                                            color: canBlock
                                                                ? scheme.error
                                                                : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ),
                              );
                            },
                            childCount: list.length,
                          ),
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

String _normalizeStateForFilter(String rawState) {
  final s = rawState.trim();
  if (s.isEmpty) return '';
  final n = int.tryParse(s);
  if (n == null) return s.toUpperCase();
  switch (n) {
    case 1:
      return 'CLOSED';
    case 2:
      return 'LISTEN';
    case 3:
      return 'SYN_SENT';
    case 4:
      return 'SYN_RECV';
    case 5:
      return 'ESTABLISHED';
    case 6:
      return 'FIN_WAIT1';
    case 7:
      return 'FIN_WAIT2';
    case 8:
      return 'CLOSE_WAIT';
    case 9:
      return 'CLOSING';
    case 10:
      return 'LAST_ACK';
    case 11:
      return 'TIME_WAIT';
    case 12:
      return 'DELETE_TCB';
    default:
      return 'STATE_$n';
  }
}

Color _stateColor(ColorScheme scheme, String state) {
  switch (state) {
    case 'ESTABLISHED':
      // Bright cyan: clear "active" signal.
      return const Color(0xFF2FD9F4);
    case 'LISTEN':
      // Amber/yellow: distinct from ESTABLISHED at quick glance.
      return const Color(0xFFFFC857);
    case 'TIME_WAIT':
      return const Color(0xFF6CD3FF);
    case 'CLOSE_WAIT':
      return scheme.error; // pink/red is already high contrast
    case 'SYN_SENT':
    case 'SYN_RECV':
      return const Color(0xFF4D7CFE);
    case 'FIN_WAIT1':
    case 'FIN_WAIT2':
    case 'CLOSING':
    case 'LAST_ACK':
      return const Color(0xFF9B8CFF);
    case 'CLOSED':
    case 'DELETE_TCB':
      return scheme.outline;
    default:
      return scheme.onSurfaceVariant;
  }
}

bool _matchesGeoFilter(NetworkConnection n, String geo) {
  final cc = n.countryCode.trim().toUpperCase();
  if (cc.isEmpty) return false;

  switch (geo) {
    case 'na':
      return const {
        'US', 'CA', 'MX', 'GL', 'BM',
      }.contains(cc);
    case 'eu':
      return const {
        'AL', 'AD', 'AT', 'BY', 'BE', 'BA', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE',
        'GI', 'GR', 'VA', 'HU', 'IS', 'IE', 'IT', 'LV', 'LI', 'LT', 'LU', 'MT', 'MD', 'MC', 'ME',
        'NL', 'MK', 'NO', 'PL', 'PT', 'RO', 'RU', 'SM', 'RS', 'SK', 'SI', 'ES', 'SE', 'CH', 'UA',
        'GB',
      }.contains(cc);
    case 'as':
      return const {
        'AF', 'AM', 'AZ', 'BH', 'BD', 'BT', 'BN', 'KH', 'CN', 'GE', 'HK', 'IN', 'ID', 'IR', 'IQ',
        'IL', 'JP', 'JO', 'KZ', 'KW', 'KG', 'LA', 'LB', 'MO', 'MY', 'MV', 'MN', 'MM', 'NP', 'KP',
        'OM', 'PK', 'PS', 'PH', 'QA', 'SA', 'SG', 'KR', 'LK', 'SY', 'TW', 'TJ', 'TH', 'TL', 'TR',
        'TM', 'AE', 'UZ', 'VN', 'YE',
      }.contains(cc);
    default:
      return true;
  }
}

class _Fv {
  const _Fv(this.value, this.label);
  final String value;
  final String label;
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<_Fv> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: EmDesign.labelCaps(context, scheme),
            ),
          ),
          InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: scheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
                items: items
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.value,
                        child: Text(e.label),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
