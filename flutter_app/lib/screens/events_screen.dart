import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/events_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

/// Sysmon event types we filter on — matches [SysmonEvent.type] from the agent.
const _kTypeTerminate = 'ProcessTerminate';
const _kTypeNetwork = 'NetworkConnect';
const _kTypeProcess = 'ProcessCreate';
const _kTypeDns = 'DnsQuery';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _search = TextEditingController();

  /// Empty set = show all types (no type filter).
  final Set<String> _typeFilter = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EventsBloc>().loadRecent(limit: 1000);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _typeFilter.clear();
      _search.clear();
    });
  }

  bool _passesTypeFilter(SysmonEvent e) {
    if (_typeFilter.isEmpty) return true;
    return _typeFilter.contains(e.type);
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
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurface,
              backgroundColor: scheme.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                side: BorderSide(color: EmDesign.ghostLine(scheme)),
              ),
            ),
            onPressed: () async {
              try {
                final p = await SharedPreferences.getInstance();
                final base =
                    p.getString('em_http_base') ?? 'http://192.168.1.10:5000';
                const s = FlutterSecureStorage();
                final token = await s.read(key: 'em_token') ?? '';
                final dio = Dio(BaseOptions(baseUrl: base));
                final res = await dio.get<dynamic>(
                  '/export/events',
                  options: Options(headers: {'Authorization': 'Bearer $token'}),
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
            },
            icon:
                Icon(Icons.ios_share_rounded, size: 18, color: scheme.primary),
            label: Text(
              'Export',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
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
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Terminate',
                          dotColor: scheme.error,
                          selected: _typeFilter.contains(_kTypeTerminate),
                          onTap: () => setState(() {
                            if (!_typeFilter.remove(_kTypeTerminate)) {
                              _typeFilter.add(_kTypeTerminate);
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Network',
                          dotColor: const Color(0xFFFBBF24),
                          selected: _typeFilter.contains(_kTypeNetwork),
                          onTap: () => setState(() {
                            if (!_typeFilter.remove(_kTypeNetwork)) {
                              _typeFilter.add(_kTypeNetwork);
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Process',
                          dotColor: scheme.primary,
                          selected: _typeFilter.contains(_kTypeProcess),
                          onTap: () => setState(() {
                            if (!_typeFilter.remove(_kTypeProcess)) {
                              _typeFilter.add(_kTypeProcess);
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'DNS',
                          dotColor: scheme.tertiary,
                          selected: _typeFilter.contains(_kTypeDns),
                          onTap: () => setState(() {
                            if (!_typeFilter.remove(_kTypeDns)) {
                              _typeFilter.add(_kTypeDns);
                            }
                          }),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: 1,
                            height: 16,
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Clear Filters',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<EventsBloc, EventsState>(
              builder: (context, state) {
                final q = _search.text.trim().toLowerCase();
                final list = state.items.where((e) {
                  if (!_passesTypeFilter(e)) return false;
                  if (q.isEmpty) return true;
                  return e.processName.toLowerCase().contains(q) ||
                      (e.commandLine?.toLowerCase().contains(q) ?? false) ||
                      (e.dnsQuery?.toLowerCase().contains(q) ?? false) ||
                      (e.remoteAddress?.toLowerCase().contains(q) ?? false) ||
                      e.type.toLowerCase().contains(q) ||
                      '${e.eventId}'.contains(q);
                }).toList();

                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No events yet',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.builder(
                  primary: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'LIVE FEED',
                          style: EmDesign.labelCaps(context, scheme),
                        ),
                      );
                    }
                    final e = list[i - 1];
                    final ts = DateTime.tryParse(e.timestamp);
                    final tsText = ts != null
                        ? DateFormat('HH:mm:ss.SSS').format(ts.toLocal())
                        : e.timestamp;
                    final vis = _styleFor(e, scheme);
                    final title =
                        e.processName.isEmpty ? e.type : e.processName;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              backgroundColor: scheme.surfaceContainerHigh,
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 4,
                                  color: vis.accent.withValues(alpha: 0.65),
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
                                              decoration: BoxDecoration(
                                                color: vis.iconBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
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
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: scheme.onSurface,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Event ID: ${e.eventId}',
                                                    style: theme
                                                        .textTheme.labelSmall
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: scheme
                                                    .surfaceContainerLowest,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tsText,
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _descriptionPreview(e),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: scheme.onSecondaryContainer,
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
                );
              },
            ),
          ),
        ],
      ),
    );
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bg =
        selected ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
