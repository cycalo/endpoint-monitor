import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/events_bloc.dart';
import '../mixins/auto_close_transient_routes_on_leave_mixin.dart';
import '../models/ws_models.dart';
import '../settings/app_settings_keys.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

/// Sysmon event types we filter on — matches [SysmonEvent.type] from the agent.
const _kTypeTerminate = 'ProcessTerminate';
const _kTypeNetwork = 'NetworkConnect';
const _kTypeProcess = 'ProcessCreate';
const _kTypeDns = 'DnsQuery';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.focusHourUtc});

  /// When set, loads events in `[hour, hour+1)` UTC from the service.
  final String? focusHourUtc;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with AutoCloseTransientRoutesOnLeaveMixin {
  @override
  String get tabPathPrefix => '/events';

  final _search = TextEditingController();

  Set<String> _noiseProcessNames = {};

  /// Empty set = show all types (no type filter).
  final Set<String> _typeFilter = {};

  /// When true: bypasses the default noise filter (shows everything).
  bool _showAllEvents = false;

  bool _onlyRemoteEndpoint = false;
  bool _onlyCommandLine = false;
  String _processNameFilter = '';

  /// 0 = all time, else minutes.
  int _timeRangeMinutes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final p = await SharedPreferences.getInstance();
      await AppSettingsKeys.ensureDefaults(p);
      final noiseCsv = p.getString(AppSettingsKeys.noiseProcesses) ?? AppSettingsKeys.defaultNoiseCsv;
      final noise = noiseCsv.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
      final range = p.getString(AppSettingsKeys.eventsDefaultRange) ?? AppSettingsKeys.defaultEventsRange;
      final maxLoad = p.getInt(AppSettingsKeys.eventsMaxLoad) ?? AppSettingsKeys.defaultEventsMaxLoad;
      int minutes = 0;
      switch (range) {
        case '15m':
          minutes = 15;
          break;
        case '1h':
          minutes = 60;
          break;
        case '6h':
          minutes = 360;
          break;
        default:
          minutes = 0;
      }
      if (!mounted) return;
      setState(() {
        _noiseProcessNames = noise;
        _timeRangeMinutes = minutes;
      });
      if (!mounted) return;
      final hour = widget.focusHourUtc;
      if (hour != null && hour.isNotEmpty) {
        final start = DateTime.tryParse(hour)?.toUtc();
        if (start != null) {
          final end = start.add(const Duration(hours: 1));
          context.read<EventsBloc>().loadRecent(
                limit: maxLoad.clamp(50, 500),
                fromIso: start.toIso8601String(),
                toIso: end.toIso8601String(),
              );
          return;
        }
      }
      context.read<EventsBloc>().loadRecent(limit: maxLoad.clamp(50, 500));
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _typeFilter.isNotEmpty ||
      _showAllEvents ||
      _onlyRemoteEndpoint ||
      _onlyCommandLine ||
      _processNameFilter.trim().isNotEmpty ||
      _timeRangeMinutes > 0;

  bool _isNoiseEvent(SysmonEvent e) {
    final name = e.processName.trim().toLowerCase();
    if (name.isEmpty) return false;
    final normalized = name.endsWith('.exe') ? name : '$name.exe';
    return _noiseProcessNames.contains(normalized);
  }

  String _filterSummaryText() {
    final parts = <String>[];
    if (_typeFilter.isNotEmpty) {
      for (final t in _typeFilter) {
        if (t == _kTypeNetwork) parts.add('Network');
        if (t == _kTypeProcess) parts.add('Process');
        if (t == _kTypeTerminate) parts.add('Terminate');
        if (t == _kTypeDns) parts.add('DNS');
      }
    }
    if (_showAllEvents) parts.add('Show all');
    if (_onlyRemoteEndpoint) parts.add('Remote only');
    if (_onlyCommandLine) parts.add('Has command line');
    final p = _processNameFilter.trim();
    if (p.isNotEmpty) parts.add('Process: $p');
    if (_timeRangeMinutes > 0) {
      parts.add(_timeRangeMinutes >= 60
          ? 'Last ${(_timeRangeMinutes / 60).round()}h'
          : 'Last ${_timeRangeMinutes}m');
    }

    if (parts.isEmpty) return 'Filtering: All';
    return 'Filtering: ${parts.join(' · ')}';
  }

  bool _passesTypeFilter(SysmonEvent e) {
    if (_typeFilter.isEmpty) return true;
    return _typeFilter.contains(e.type);
  }

  Future<void> _openFiltersSheet() async {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final result = await showModalBottomSheet<_EventsFilterResult>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (c) {
        var tempTypes = {..._typeFilter};
        var tempShowAll = _showAllEvents;
        var tempOnlyRemote = _onlyRemoteEndpoint;
        var tempOnlyCmd = _onlyCommandLine;
        var tempProcess = _processNameFilter;
        var tempTimeRangeMinutes = _timeRangeMinutes;

        void clearAll(StateSetter setModalState) {
          setModalState(() {
            tempTypes.clear();
            tempShowAll = false;
            tempOnlyRemote = false;
            tempOnlyCmd = false;
            tempProcess = '';
            tempTimeRangeMinutes = 0;
          });
        }

        void toggleType(StateSetter setModalState, String type) {
          setModalState(() {
            if (!tempTypes.remove(type)) {
              tempTypes.add(type);
            }
          });
        }

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
                heightFactor: 0.92,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
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
                              onPressed: () => clearAll(setModalState),
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
                                  _SheetCheckRow(
                                    label: 'Terminate',
                                    checked:
                                        tempTypes.contains(_kTypeTerminate),
                                    onTap: () => toggleType(
                                      setModalState,
                                      _kTypeTerminate,
                                    ),
                                  ),
                                  _SheetCheckRow(
                                    label: 'Network',
                                    checked: tempTypes.contains(_kTypeNetwork),
                                    onTap: () => toggleType(
                                      setModalState,
                                      _kTypeNetwork,
                                    ),
                                  ),
                                  _SheetCheckRow(
                                    label: 'Process',
                                    checked: tempTypes.contains(_kTypeProcess),
                                    onTap: () => toggleType(
                                      setModalState,
                                      _kTypeProcess,
                                    ),
                                  ),
                                  _SheetCheckRow(
                                    label: 'DNS',
                                    checked: tempTypes.contains(_kTypeDns),
                                    onTap: () => toggleType(
                                      setModalState,
                                      _kTypeDns,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                              child: OutlinedButton.icon(
                                onPressed: tempTypes.isEmpty
                                    ? null
                                    : () =>
                                        setModalState(() => tempTypes.clear()),
                                icon: const Icon(Icons.restart_alt_rounded,
                                    size: 18),
                                label: const Text('Show all types'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  side: BorderSide(
                                    color: scheme.outlineVariant
                                        .withValues(alpha: 0.25),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        EmDesign.radiusLg),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            cardChild(
                              Column(
                                children: [
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Column(
                                      children: [
                                        SwitchListTile.adaptive(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 2,
                                          ),
                                          value: tempShowAll,
                                          onChanged: (v) => setModalState(
                                            () => tempShowAll = v,
                                          ),
                                          title: const Text('Show all events'),
                                        ),
                                        SwitchListTile.adaptive(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 2,
                                          ),
                                          value: tempOnlyRemote,
                                          onChanged: (v) => setModalState(
                                            () => tempOnlyRemote = v,
                                          ),
                                          title: const Text(
                                            'Remote endpoint only',
                                          ),
                                        ),
                                        SwitchListTile.adaptive(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 2,
                                          ),
                                          value: tempOnlyCmd,
                                          onChanged: (v) => setModalState(
                                            () => tempOnlyCmd = v,
                                          ),
                                          title: const Text('Has command line'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 6, 16, 14),
                                    child: TextField(
                                      controller: TextEditingController(
                                          text: tempProcess)
                                        ..selection = TextSelection.collapsed(
                                          offset: tempProcess.length,
                                        ),
                                      onChanged: (v) =>
                                          setModalState(() => tempProcess = v),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Process name',
                                        hintText: 'e.g. chrome.exe',
                                        isDense: true,
                                        filled: true,
                                        fillColor:
                                            scheme.surfaceContainerLowest,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            EmDesign.radiusLg,
                                          ),
                                          borderSide: BorderSide(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.18),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            EmDesign.radiusLg,
                                          ),
                                          borderSide: BorderSide(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.18),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            EmDesign.radiusLg,
                                          ),
                                          borderSide: BorderSide(
                                            color: scheme.primary,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            cardChild(
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _TimeRangeChip(
                                      label: 'All',
                                      selected: tempTimeRangeMinutes == 0,
                                      onTap: () => setModalState(
                                        () => tempTimeRangeMinutes = 0,
                                      ),
                                    ),
                                    _TimeRangeChip(
                                      label: '15m',
                                      selected: tempTimeRangeMinutes == 15,
                                      onTap: () => setModalState(
                                        () => tempTimeRangeMinutes = 15,
                                      ),
                                    ),
                                    _TimeRangeChip(
                                      label: '1h',
                                      selected: tempTimeRangeMinutes == 60,
                                      onTap: () => setModalState(
                                        () => tempTimeRangeMinutes = 60,
                                      ),
                                    ),
                                    _TimeRangeChip(
                                      label: '6h',
                                      selected: tempTimeRangeMinutes == 360,
                                      onTap: () => setModalState(
                                        () => tempTimeRangeMinutes = 360,
                                      ),
                                    ),
                                  ],
                                ),
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
                                onPressed: () {
                                  Navigator.pop(
                                    c,
                                    _EventsFilterResult(
                                      types: tempTypes,
                                      showAllEvents: tempShowAll,
                                      onlyRemoteEndpoint: tempOnlyRemote,
                                      onlyCommandLine: tempOnlyCmd,
                                      processNameFilter: tempProcess,
                                      timeRangeMinutes: tempTimeRangeMinutes,
                                    ),
                                  );
                                },
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _typeFilter
        ..clear()
        ..addAll(result.types);
      _showAllEvents = result.showAllEvents;
      _onlyRemoteEndpoint = result.onlyRemoteEndpoint;
      _onlyCommandLine = result.onlyCommandLine;
      _processNameFilter = result.processNameFilter;
      _timeRangeMinutes = result.timeRangeMinutes;
    });
  }

  _EventVisualStyle _styleFor(SysmonEvent e, ColorScheme scheme) {
    switch (e.type) {
      case _kTypeTerminate:
        return _EventVisualStyle(
          accent: scheme.error,
          iconBg: scheme.errorContainer.withValues(alpha: 0.2),
          icon: Icons.dangerous_rounded,
        );
      case _kTypeNetwork:
        return _EventVisualStyle(
          accent: const Color(0xFFFBBF24),
          iconBg: const Color(0xFFFBBF24).withValues(alpha: 0.12),
          icon: Icons.lan_rounded,
        );
      case _kTypeProcess:
        return _EventVisualStyle(
          accent: scheme.primary,
          iconBg: scheme.primaryContainer.withValues(alpha: 0.2),
          icon: Icons.info_rounded,
        );
      case _kTypeDns:
        return _EventVisualStyle(
          accent: scheme.tertiary,
          iconBg: scheme.tertiaryContainer.withValues(alpha: 0.12),
          icon: Icons.dns_rounded,
        );
      default:
        return _EventVisualStyle(
          accent: scheme.outline,
          iconBg: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          icon: Icons.event_note_rounded,
        );
    }
  }

  String _descriptionPreview(SysmonEvent e) {
    if (e.commandLine != null && e.commandLine!.trim().isNotEmpty) {
      return e.commandLine!.trim();
    }
    if (e.dnsQuery != null && e.dnsQuery!.trim().isNotEmpty) {
      return 'Query: ${e.dnsQuery}';
    }
    if (e.remoteAddress != null && e.remoteAddress!.trim().isNotEmpty) {
      return '${e.remoteAddress}:${e.remotePort ?? 0}';
    }
    final raw = e.rawXml.trim();
    if (raw.length <= 220) return raw;
    return '${raw.substring(0, 220)}…';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        actions: [
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
          Builder(
            builder: (context) {
              final isNarrow = MediaQuery.sizeOf(context).width < 460;
              Future<void> exportEvents() async {
                try {
                  final p = await SharedPreferences.getInstance();
                  final base =
                      p.getString('em_http_base') ?? 'http://192.168.1.10:5000';
                  const s = FlutterSecureStorage();
                  final token = await s.read(key: 'em_token') ?? '';
                  final dio = Dio(BaseOptions(baseUrl: base));
                  final res = await dio.get<dynamic>(
                    '/export/events',
                    options:
                        Options(headers: {'Authorization': 'Bearer $token'}),
                  );
                  if (!context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Export preview'),
                      content: SingleChildScrollView(
                        child: Text(() {
                          final str = res.data?.toString() ?? '';
                          if (str.length <= 4000) return str;
                          return '${str.substring(0, 4000)}…';
                        }()),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }

              if (isNarrow) {
                return IconButton(
                  tooltip: 'Export (HTTP)',
                  onPressed: exportEvents,
                  icon: Icon(Icons.ios_share_rounded, color: scheme.primary),
                );
              }

              return TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  backgroundColor: scheme.surfaceContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                    side: BorderSide(color: EmDesign.ghostLine(scheme)),
                  ),
                ),
                onPressed: exportEvents,
                icon: Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                label: Text(
                  'Export',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surfaceContainerLow,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerLowest,
                      hintText: 'Search events...',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                        borderSide:
                            BorderSide(color: scheme.primary, width: 1.2),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (widget.focusHourUtc != null &&
                      widget.focusHourUtc!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 18, color: scheme.tertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'One-hour window from timeline (UTC).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    )
                  else if (widget.focusHourUtc == null ||
                      widget.focusHourUtc!.isEmpty)
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<EventsBloc, EventsState>(
              builder: (context, state) {
                final q = _search.text.trim().toLowerCase();
                final cutoff = _timeRangeMinutes <= 0
                    ? null
                    : DateTime.now().toUtc().subtract(
                          Duration(minutes: _timeRangeMinutes),
                        );
                final filtered = state.items.where((e) {
                  if (!_showAllEvents && _isNoiseEvent(e)) return false;
                  if (!_passesTypeFilter(e)) return false;
                  final pn = _processNameFilter.trim().toLowerCase();
                  if (pn.isNotEmpty) {
                    if (!e.processName.toLowerCase().contains(pn)) return false;
                  }
                  if (cutoff != null) {
                    final ts = DateTime.tryParse(e.timestamp);
                    if (ts == null) return false;
                    if (ts.toUtc().isBefore(cutoff)) return false;
                  }
                  if (_onlyRemoteEndpoint) {
                    final hasRemote =
                        (e.remoteAddress?.trim().isNotEmpty ?? false) &&
                            (e.remotePort ?? 0) > 0;
                    if (!hasRemote) return false;
                  }
                  if (_onlyCommandLine) {
                    if (!(e.commandLine?.trim().isNotEmpty ?? false)) {
                      return false;
                    }
                  }
                  if (q.isEmpty) return true;
                  return e.processName.toLowerCase().contains(q) ||
                      (e.commandLine?.toLowerCase().contains(q) ?? false) ||
                      (e.dnsQuery?.toLowerCase().contains(q) ?? false) ||
                      (e.remoteAddress?.toLowerCase().contains(q) ?? false) ||
                      e.type.toLowerCase().contains(q) ||
                      '${e.eventId}'.contains(q);
                }).toList();
                final list = filtered;

                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No events yet',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  );
                }

                return CustomScrollView(
                  primary: true,
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _LiveFeedBarDelegate(
                        scheme: scheme,
                        shown: list.length,
                        total: state.items.length,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final e = list[index];
                            final ts = DateTime.tryParse(e.timestamp);
                            final tsText = ts != null
                                ? DateFormat('HH:mm:ss.SSS')
                                    .format(ts.toLocal())
                                : e.timestamp;
                            final vis = _styleFor(e, scheme);
                            final title = e.processName.isEmpty
                                ? e.type
                                : e.processName;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: scheme.surfaceContainer,
                                borderRadius:
                                    BorderRadius.circular(EmDesign.radiusLg),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    showModalBottomSheet<void>(
                                      context: context,
                                      useRootNavigator: true,
                                      showDragHandle: true,
                                      backgroundColor:
                                          scheme.surfaceContainerHigh,
                                      builder: (c) => Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: ListView(
                                          children: [
                                            Text(
                                              'PID ${e.pid}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(height: 8),
                                            SelectableText(e.rawXml),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 4,
                                          color: vis.accent
                                              .withValues(alpha: 0.65),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration:
                                                          BoxDecoration(
                                                        color: vis.iconBg,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Icon(
                                                        vis.icon,
                                                        size: 22,
                                                        color: vis.accent,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            title,
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: scheme
                                                                  .onSurface,
                                                              height: 1.2,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            'Event ID: ${e.eventId}',
                                                            style: theme
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                              fontSize: 10,
                                                              color: scheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: vis.accent
                                                            .withValues(
                                                                alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        tsText,
                                                        style: theme
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: vis.accent,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  _descriptionPreview(e),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: scheme
                                                        .onSecondaryContainer,
                                                    height: 1.45,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
}

class _LiveFeedBarDelegate extends SliverPersistentHeaderDelegate {
  _LiveFeedBarDelegate({
    required this.scheme,
    required this.shown,
    required this.total,
  });

  final ColorScheme scheme;
  final int shown;
  final int total;

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
            Text(
              'Live feed',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.bolt_rounded,
              size: 18,
              color: scheme.tertiary,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$shown / $total shown',
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
  bool shouldRebuild(covariant _LiveFeedBarDelegate oldDelegate) {
    return oldDelegate.scheme != scheme ||
        oldDelegate.shown != shown ||
        oldDelegate.total != total;
  }
}

class _EventVisualStyle {
  const _EventVisualStyle({
    required this.accent,
    required this.iconBg,
    required this.icon,
  });

  final Color accent;
  final Color iconBg;
  final IconData icon;
}

class _EventsFilterResult {
  const _EventsFilterResult({
    required this.types,
    required this.showAllEvents,
    required this.onlyRemoteEndpoint,
    required this.onlyCommandLine,
    required this.processNameFilter,
    required this.timeRangeMinutes,
  });

  final Set<String> types;
  final bool showAllEvents;
  final bool onlyRemoteEndpoint;
  final bool onlyCommandLine;
  final String processNameFilter;
  final int timeRangeMinutes;
}

class _SheetCheckRow extends StatelessWidget {
  const _SheetCheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
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
                color: checked
                    ? scheme.primary.withValues(alpha: 0.2)
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked
                      ? scheme.primary.withValues(alpha: 0.8)
                      : scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 16, color: scheme.primary)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRangeChip extends StatelessWidget {
  const _TimeRangeChip({
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
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.16)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.7)
                  : scheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
