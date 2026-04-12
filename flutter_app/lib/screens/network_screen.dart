import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/blocked_remote_ips_cubit.dart';
import '../bloc/network_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../bloc/threat_intel_bloc.dart';
import '../mixins/auto_close_transient_routes_on_leave_mixin.dart';
import '../models/ws_models.dart';
import '../settings/app_settings_keys.dart';
import '../theme/em_design_system.dart';
import '../utils/country_flag_emoji.dart';
import '../utils/ip_normalize.dart';
import '../utils/network_endpoint_display.dart';
import '../utils/throughput_format.dart';
import '../widgets/em_brand_app_bar.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key, this.highlightThreats = false});

  /// Deep link from dashboard — prioritize rows that match the threat IP list.
  final bool highlightThreats;

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with AutoCloseTransientRoutesOnLeaveMixin {
  @override
  String get tabPathPrefix => '/network';

  final _search = TextEditingController();
  String _protocol = 'all';
  String _state = 'all';
  String _geo = 'all';

  /// `all` | `blocked` | `unblocked` — client-tracked firewall blocks.
  String _blockedScope = 'all';

  /// When false, rows whose remote address is IPv6 are hidden (IPv4-first list).
  bool _showIpv6 = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _showIpv6 = p.getBool(AppSettingsKeys.showIpv6Network) ?? false;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ThreatIntelBloc>().refreshEntries();
    });
  }

  bool get _hasActiveFilters =>
      _protocol != 'all' ||
      _state != 'all' ||
      _geo != 'all' ||
      _blockedScope != 'all';

  String _filterSummaryText() {
    final parts = <String>[];
    if (_protocol != 'all') parts.add('Protocol: $_protocol');
    if (_state != 'all') parts.add('State: $_state');
    if (_geo != 'all') {
      switch (_geo) {
        case 'na':
          parts.add('Geo: North America');
          break;
        case 'eu':
          parts.add('Geo: Europe');
          break;
        case 'as':
          parts.add('Geo: Asia');
          break;
        default:
          break;
      }
    }
    if (_blockedScope == 'blocked') {
      parts.add('Blocked only');
    } else if (_blockedScope == 'unblocked') {
      parts.add('Not blocked');
    }
    if (parts.isEmpty) return 'Filtering: All';
    return 'Filtering: ${parts.join(' · ')}';
  }

  Future<void> _openFiltersSheet() async {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<_NetworkFilterResult>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (c) {
        var tempProtocol = _protocol;
        var tempState = _state;
        var tempGeo = _geo;
        var tempBlockedScope = _blockedScope;

        Widget cardChild(Widget child) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: EmDesign.cardShell(
                scheme,
                color: scheme.surfaceContainer,
                radius: EmDesign.radiusLg,
              ),
              child: child,
            );

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.84,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filters',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setModalState(() {
                              tempProtocol = 'all';
                              tempState = 'all';
                              tempGeo = 'all';
                              tempBlockedScope = 'all';
                            }),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          cardChild(
                            Column(
                              children: [
                                _SheetRadioRow(
                                  label: 'All protocols',
                                  selected: tempProtocol == 'all',
                                  onTap: () =>
                                      setModalState(() => tempProtocol = 'all'),
                                ),
                                _SheetRadioRow(
                                  label: 'TCP',
                                  selected: tempProtocol == 'TCP',
                                  onTap: () =>
                                      setModalState(() => tempProtocol = 'TCP'),
                                ),
                                _SheetRadioRow(
                                  label: 'UDP',
                                  selected: tempProtocol == 'UDP',
                                  onTap: () =>
                                      setModalState(() => tempProtocol = 'UDP'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          cardChild(
                            Column(
                              children: [
                                _SheetRadioRow(
                                  label: 'All states',
                                  selected: tempState == 'all',
                                  onTap: () =>
                                      setModalState(() => tempState = 'all'),
                                ),
                                _SheetRadioRow(
                                  label: 'Established',
                                  selected: tempState == 'ESTABLISHED',
                                  onTap: () => setModalState(
                                      () => tempState = 'ESTABLISHED'),
                                ),
                                _SheetRadioRow(
                                  label: 'Listening',
                                  selected: tempState == 'LISTEN',
                                  onTap: () =>
                                      setModalState(() => tempState = 'LISTEN'),
                                ),
                                _SheetRadioRow(
                                  label: 'Time wait',
                                  selected: tempState == 'TIME_WAIT',
                                  onTap: () => setModalState(
                                      () => tempState = 'TIME_WAIT'),
                                ),
                                _SheetRadioRow(
                                  label: 'Blocked (firewall)',
                                  selected: tempState == 'BLOCKED',
                                  onTap: () => setModalState(
                                      () => tempState = 'BLOCKED'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          cardChild(
                            Column(
                              children: [
                                _SheetRadioRow(
                                  label: 'All blocked / unblocked',
                                  selected: tempBlockedScope == 'all',
                                  onTap: () => setModalState(
                                      () => tempBlockedScope = 'all'),
                                ),
                                _SheetRadioRow(
                                  label: 'Blocked only',
                                  selected: tempBlockedScope == 'blocked',
                                  onTap: () => setModalState(
                                      () => tempBlockedScope = 'blocked'),
                                ),
                                _SheetRadioRow(
                                  label: 'Not blocked',
                                  selected: tempBlockedScope == 'unblocked',
                                  onTap: () => setModalState(
                                      () => tempBlockedScope = 'unblocked'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          cardChild(
                            Column(
                              children: [
                                _SheetRadioRow(
                                  label: 'Global',
                                  selected: tempGeo == 'all',
                                  onTap: () =>
                                      setModalState(() => tempGeo = 'all'),
                                ),
                                _SheetRadioRow(
                                  label: 'North America',
                                  selected: tempGeo == 'na',
                                  onTap: () =>
                                      setModalState(() => tempGeo = 'na'),
                                ),
                                _SheetRadioRow(
                                  label: 'Europe',
                                  selected: tempGeo == 'eu',
                                  onTap: () =>
                                      setModalState(() => tempGeo = 'eu'),
                                ),
                                _SheetRadioRow(
                                  label: 'Asia',
                                  selected: tempGeo == 'as',
                                  onTap: () =>
                                      setModalState(() => tempGeo = 'as'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(
                                c,
                                _NetworkFilterResult(
                                  protocol: tempProtocol,
                                  state: tempState,
                                  geo: tempGeo,
                                  blockedScope: tempBlockedScope,
                                ),
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      _protocol = result.protocol;
      _state = result.state;
      _geo = result.geo;
      _blockedScope = result.blockedScope;
    });
  }

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
    if (n.contains('system') || n.contains('svchost')) {
      return Icons.settings_rounded;
    }
    return Icons.hub_rounded;
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
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFiltersSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.filter_alt_rounded, color: scheme.primary),
                if (_hasActiveFilters)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.tertiary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.tertiary.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BlocBuilder<BlockedRemoteIpsCubit, Map<String, BlockedRemoteMeta>>(
              builder: (context, blockedMap) {
                return BlocBuilder<ThreatIntelBloc, ThreatIntelState>(
                  builder: (context, ti) {
                return BlocBuilder<NetworkBloc, NetworkState>(
                  builder: (context, state) {
                if (state.loading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final merged =
                    _mergeWithBlockedPlaceholders(state.items, blockedMap);

                final q = _search.text.trim().toLowerCase();
                var list = merged.where((n) {
                  if (_protocol != 'all' && n.protocol != _protocol) {
                    return false;
                  }
                  final normalizedState = _normalizeStateForFilter(n.state);
                  if (_state != 'all') {
                    if (n.protocol.toUpperCase() == 'TCP') {
                      if (normalizedState != _state) return false;
                    } else if (normalizedState == 'BLOCKED') {
                      if (_state != 'BLOCKED') return false;
                    }
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

                if (!_showIpv6) {
                  list = list.where((n) {
                    final r = n.remoteAddress.trim();
                    if (r.isEmpty) {
                      return true;
                    }
                    return !isIpv6Address(r);
                  }).toList();
                }

                switch (_blockedScope) {
                  case 'blocked':
                    list = list
                        .where((n) => _rowIsBlocked(n, blockedMap))
                        .toList();
                    break;
                  case 'unblocked':
                    list = list
                        .where((n) => !_rowIsBlocked(n, blockedMap))
                        .toList();
                    break;
                }

                if (widget.highlightThreats) {
                  list.sort((a, b) {
                    final ta = ti.lookupIp(normalizeIpForBlockList(a.remoteAddress)) != null;
                    final tb = ti.lookupIp(normalizeIpForBlockList(b.remoteAddress)) != null;
                    if (ta != tb) return ta ? -1 : 1;
                    return b.remoteAddress.compareTo(a.remoteAddress);
                  });
                } else {
                  list.sort((a, b) => b.remoteAddress.compareTo(a.remoteAddress));
                }

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: BlocBuilder<SystemInfoBloc, SystemInfoState>(
                          builder: (context, si) {
                            final uptime =
                                si.info?.uptime.trim().isEmpty ?? true
                                    ? '—'
                                    : si.info!.uptime.trim();
                            final upMbps = formatMbpsFromBytesPerSec(
                                si.info?.networkBytesSentPerSec ?? 0);
                            final downMbps = formatMbpsFromBytesPerSec(
                                si.info?.networkBytesReceivedPerSec ?? 0);
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh
                                    .withValues(alpha: 0.5),
                                borderRadius:
                                    BorderRadius.circular(EmDesign.radiusLg),
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.speed_rounded,
                                      color: scheme.primary, size: 26),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SYSTEM NETWORK',
                                          style: EmDesign.labelCaps(
                                              context, scheme),
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
                                                  color:
                                                      scheme.onSurfaceVariant,
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
                                                  color:
                                                      scheme.onSurfaceVariant,
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
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurface),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: scheme.surfaceContainer,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 14),
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: scheme.outline),
                                hintText:
                                    'Search process names or IP addresses',
                                hintStyle: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.outline.withValues(alpha: 0.7),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(EmDesign.radiusMd),
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
                                        icon: Icon(Icons.clear_rounded,
                                            color: scheme.outline, size: 22),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_hasActiveFilters)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  _filterSummaryText(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ActiveConnectionsBarDelegate(
                        scheme: scheme,
                        activeCount: list.length,
                        showIpv6: _showIpv6,
                        onIpv6Changed: (v) => setState(() => _showIpv6 = v),
                      ),
                    ),
                    if (list.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No matching connections',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
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
                              final canBlock =
                                  hasBlockableRemoteEndpoint(n.remoteAddress);
                              final blocked = _rowIsBlocked(n, blockedMap);
                              final threat = ti.lookupIp(
                                  normalizeIpForBlockList(n.remoteAddress));
                              final normalizedState =
                                  _normalizeStateForFilter(n.state);
                              final stateColor = blocked
                                  ? scheme.error
                                  : (threat != null
                                      ? scheme.tertiary
                                      : _stateColor(
                                          scheme, normalizedState));
                              final bg = i.isEven
                                  ? scheme.surfaceContainer
                                  : scheme.surfaceContainerLow;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: bg,
                                  borderRadius:
                                      BorderRadius.circular(EmDesign.radiusLg),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: 3,
                                          decoration: BoxDecoration(
                                            color: stateColor.withValues(
                                                alpha: 0.92),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(
                                                  EmDesign.radiusLg),
                                              bottom: Radius.circular(
                                                  EmDesign.radiusLg),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 42,
                                                  height: 42,
                                                  decoration: BoxDecoration(
                                                    color: scheme
                                                        .surfaceContainerLow,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            EmDesign.radiusMd),
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
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        n.processName,
                                                                        style: GoogleFonts.manrope(
                                                                          fontSize:
                                                                              14,
                                                                          fontWeight:
                                                                              FontWeight.w800,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    if (blocked)
                                                                      Padding(
                                                                        padding: const EdgeInsets
                                                                            .only(
                                                                            left:
                                                                                6),
                                                                        child:
                                                                            Container(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                          horizontal:
                                                                              6,
                                                                          vertical:
                                                                              2,
                                                                        ),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                scheme.error.withValues(alpha: 0.12),
                                                                            borderRadius:
                                                                                BorderRadius.circular(4),
                                                                            border:
                                                                                Border.all(
                                                                              color: scheme.error.withValues(alpha: 0.35),
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              Text(
                                                                            'BLOCKED',
                                                                            style:
                                                                                GoogleFonts.inter(
                                                                              fontSize:
                                                                                  9,
                                                                              fontWeight:
                                                                                  FontWeight.w800,
                                                                              letterSpacing:
                                                                                  0.4,
                                                                              color:
                                                                                  scheme.error,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    if (threat != null && !blocked)
                                                                      Padding(
                                                                        padding: const EdgeInsets.only(left: 6),
                                                                        child: Container(
                                                                          padding: const EdgeInsets.symmetric(
                                                                              horizontal: 6, vertical: 2),
                                                                          decoration: BoxDecoration(
                                                                            color: scheme.tertiary.withValues(alpha: 0.15),
                                                                            borderRadius: BorderRadius.circular(4),
                                                                            border: Border.all(
                                                                              color: scheme.tertiary.withValues(alpha: 0.4),
                                                                            ),
                                                                          ),
                                                                          child: Text(
                                                                            'THREAT IP',
                                                                            style: GoogleFonts.inter(
                                                                              fontSize: 9,
                                                                              fontWeight: FontWeight.w800,
                                                                              letterSpacing: 0.4,
                                                                              color: scheme.tertiary,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                    height: 6),
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: scheme
                                                                        .surfaceContainerHighest,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    n.state
                                                                                .trim()
                                                                                .toUpperCase() ==
                                                                            'BLOCKED' &&
                                                                        n.pid <=
                                                                            0
                                                                        ? 'PID: —'
                                                                        : 'PID: ${n.pid}',
                                                                    style: GoogleFonts
                                                                        .inter(
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: scheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (normalizedState ==
                                                                    'BLOCKED') ...[
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'No live socket in snapshot — showing process/PID from when you blocked',
                                                                    style: GoogleFonts.inter(
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      height:
                                                                          1.3,
                                                                      color: scheme
                                                                          .onSurfaceVariant
                                                                          .withValues(
                                                                              alpha:
                                                                                  0.85),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Container(
                                                                width: 8,
                                                                height: 8,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color:
                                                                      stateColor,
                                                                  boxShadow:
                                                                      normalizedState ==
                                                                              'LISTEN'
                                                                          ? null
                                                                          : [
                                                                              BoxShadow(
                                                                                color: stateColor.withValues(alpha: 0.7),
                                                                                blurRadius: 8,
                                                                              ),
                                                                            ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                '${n.protocol.toUpperCase()}  $normalizedState',
                                                                style:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  letterSpacing:
                                                                      0.45,
                                                                  color:
                                                                      stateColor,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text.rich(
                                                        TextSpan(
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 11.5,
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          children: [
                                                            const TextSpan(
                                                                text:
                                                                    'Local: '),
                                                            TextSpan(
                                                              text: formatNetworkEndpoint(
                                                                n.localAddress,
                                                                n.localPort,
                                                              ),
                                                              style: TextStyle(
                                                                  color: scheme
                                                                      .onSurface),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text.rich(
                                                        TextSpan(
                                                          style:
                                                              GoogleFonts.inter(
                                                            fontSize: 11.5,
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          children: [
                                                            const TextSpan(
                                                                text:
                                                                    'Remote: '),
                                                            TextSpan(
                                                              text: formatNetworkEndpoint(
                                                                n.remoteAddress,
                                                                n.remotePort,
                                                              ),
                                                              style: TextStyle(
                                                                color: scheme
                                                                    .tertiary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (n.city.isNotEmpty ||
                                                          n.countryName
                                                              .isNotEmpty ||
                                                          n.countryCode
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                            height: 4),
                                                        Row(
                                                          children: [
                                                            if (countryCodeToFlagEmoji(
                                                                    n.countryCode)
                                                                .isNotEmpty)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        right:
                                                                            6),
                                                                child: Text(
                                                                  countryCodeToFlagEmoji(
                                                                      n.countryCode),
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          16),
                                                                ),
                                                              ),
                                                            Expanded(
                                                              child: Text(
                                                                n.city.isNotEmpty
                                                                    ? n.city
                                                                    : (n.countryName
                                                                            .isNotEmpty
                                                                        ? n.countryName
                                                                        : n.countryCode),
                                                                style:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: scheme
                                                                      .onSurface,
                                                                ),
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
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            EmDesign.radiusSm),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 10),
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: scheme
                                                            .surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                EmDesign
                                                                    .radiusSm),
                                                      ),
                                                      child: Text(
                                                        'Details',
                                                        style:
                                                            GoogleFonts.manrope(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: !canBlock
                                                        ? null
                                                        : blocked
                                                            ? () =>
                                                                _unblock(
                                                                    context,
                                                                    n)
                                                            : () => _block(
                                                                context, n),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            EmDesign.radiusSm),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 10),
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: !canBlock
                                                            ? scheme
                                                                .surfaceContainerHighest
                                                                .withValues(
                                                                    alpha:
                                                                        0.45)
                                                            : blocked
                                                                ? scheme
                                                                    .primaryContainer
                                                                    .withValues(
                                                                        alpha:
                                                                            0.65)
                                                                : scheme
                                                                    .errorContainer,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                EmDesign
                                                                    .radiusSm),
                                                      ),
                                                      child: Text(
                                                        !canBlock
                                                            ? (isListeningStyleSocket(n)
                                                                ? 'Listen only'
                                                                : 'No remote endpoint')
                                                            : blocked
                                                                ? 'Unblock IP'
                                                                : 'Block connection',
                                                        style:
                                                            GoogleFonts.manrope(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: !canBlock
                                                              ? scheme
                                                                  .onSurfaceVariant
                                                                  .withValues(
                                                                      alpha:
                                                                          0.45)
                                                              : blocked
                                                                  ? scheme
                                                                      .primary
                                                                  : scheme
                                                                      .error,
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

  Future<void> _block(BuildContext context, NetworkConnection n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Block remote IP?'),
        content: Text(
          formatNetworkEndpoint(n.remoteAddress, n.remotePort),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Block')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<NetworkBloc>().sendCommand({
        'type': 'block_ip',
        'ip': n.remoteAddress,
        'direction': 'outbound',
        if (n.processName.isNotEmpty) 'sourceProcess': n.processName,
      });
      await context.read<BlockedRemoteIpsCubit>().add(
            n.remoteAddress,
            snapshot: n,
          );
    }
  }

  Future<void> _unblock(BuildContext context, NetworkConnection n) async {
    if (!context.mounted) return;
    context.read<NetworkBloc>().sendCommand({
      'type': 'unblock_ip',
      'ip': n.remoteAddress,
    });
    await context.read<BlockedRemoteIpsCubit>().remove(n.remoteAddress);
  }
}

List<NetworkConnection> _mergeWithBlockedPlaceholders(
  List<NetworkConnection> server,
  Map<String, BlockedRemoteMeta> blockedMap,
) {
  final seen = <String>{};
  for (final n in server) {
    final k = normalizeIpForBlockList(n.remoteAddress);
    if (k.isNotEmpty) seen.add(k);
  }
  final out = List<NetworkConnection>.from(server);
  for (final e in blockedMap.entries) {
    final ip = e.key;
    if (ip.isEmpty) continue;
    if (!seen.contains(ip)) {
      out.add(NetworkConnection.firewallBlockedPlaceholder(ip, e.value));
    }
  }
  return out;
}

bool _rowIsBlocked(
    NetworkConnection n, Map<String, BlockedRemoteMeta> blockedMap) {
  if (n.state.trim().toUpperCase() == 'BLOCKED') return true;
  final k = normalizeIpForBlockList(n.remoteAddress);
  return k.isNotEmpty && blockedMap.containsKey(k);
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
    case 'BLOCKED':
      return scheme.error;
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
        'US',
        'CA',
        'MX',
        'GL',
        'BM',
      }.contains(cc);
    case 'eu':
      return const {
        'AL',
        'AD',
        'AT',
        'BY',
        'BE',
        'BA',
        'BG',
        'HR',
        'CY',
        'CZ',
        'DK',
        'EE',
        'FI',
        'FR',
        'DE',
        'GI',
        'GR',
        'VA',
        'HU',
        'IS',
        'IE',
        'IT',
        'LV',
        'LI',
        'LT',
        'LU',
        'MT',
        'MD',
        'MC',
        'ME',
        'NL',
        'MK',
        'NO',
        'PL',
        'PT',
        'RO',
        'RU',
        'SM',
        'RS',
        'SK',
        'SI',
        'ES',
        'SE',
        'CH',
        'UA',
        'GB',
      }.contains(cc);
    case 'as':
      return const {
        'AF',
        'AM',
        'AZ',
        'BH',
        'BD',
        'BT',
        'BN',
        'KH',
        'CN',
        'GE',
        'HK',
        'IN',
        'ID',
        'IR',
        'IQ',
        'IL',
        'JP',
        'JO',
        'KZ',
        'KW',
        'KG',
        'LA',
        'LB',
        'MO',
        'MY',
        'MV',
        'MN',
        'MM',
        'NP',
        'KP',
        'OM',
        'PK',
        'PS',
        'PH',
        'QA',
        'SA',
        'SG',
        'KR',
        'LK',
        'SY',
        'TW',
        'TJ',
        'TH',
        'TL',
        'TR',
        'TM',
        'AE',
        'UZ',
        'VN',
        'YE',
      }.contains(cc);
    default:
      return true;
  }
}

class _ActiveConnectionsBarDelegate extends SliverPersistentHeaderDelegate {
  _ActiveConnectionsBarDelegate({
    required this.scheme,
    required this.activeCount,
    required this.showIpv6,
    required this.onIpv6Changed,
  });

  final ColorScheme scheme;
  final int activeCount;
  final bool showIpv6;
  final ValueChanged<bool> onIpv6Changed;

  static const double _height = 56;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: scheme.surface,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Container(
        height: _height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Active connections',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: scheme.tertiary,
                  ),
                ],
              ),
            ),
            Text(
              'IPv6',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Switch.adaptive(
              value: showIpv6,
              onChanged: onIpv6Changed,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$activeCount active',
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
    );
  }

  @override
  bool shouldRebuild(covariant _ActiveConnectionsBarDelegate oldDelegate) {
    return oldDelegate.scheme != scheme ||
        oldDelegate.activeCount != activeCount ||
        oldDelegate.showIpv6 != showIpv6;
  }
}

class _SheetRadioRow extends StatelessWidget {
  const _SheetRadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.2)
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.8)
                      : scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 16, color: scheme.primary)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkFilterResult {
  const _NetworkFilterResult({
    required this.protocol,
    required this.state,
    required this.geo,
    required this.blockedScope,
  });

  final String protocol;
  final String state;
  final String geo;
  final String blockedScope;
}
