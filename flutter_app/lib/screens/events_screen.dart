import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/events_bloc.dart';
import '../models/ws_models.dart';
import '../widgets/em_brand_app_bar.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _search = TextEditingController();
  String _type = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Color _colorFor(SysmonEvent e, ColorScheme scheme) {
    return switch (e.type) {
      'ProcessCreate' => scheme.primary,
      'NetworkConnect' => scheme.tertiary,
      'DnsQuery' => scheme.secondaryContainer,
      'ProcessTerminate' => scheme.error,
      _ => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        actions: [
          IconButton(
            tooltip: 'Export (HTTP)',
            onPressed: () async {
              try {
                final p = await SharedPreferences.getInstance();
                final base = p.getString('em_http_base') ?? 'http://192.168.1.10:5000';
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
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            icon: const Icon(Icons.download_outlined),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'ProcessCreate', child: Text('Process')),
                    DropdownMenuItem(value: 'NetworkConnect', child: Text('Network')),
                    DropdownMenuItem(value: 'DnsQuery', child: Text('DNS')),
                    DropdownMenuItem(value: 'ProcessTerminate', child: Text('Terminate')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'all'),
                ),
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          final theme = Theme.of(context);
          final q = _search.text.trim().toLowerCase();
          final list = state.items.where((e) {
            if (_type != 'all' && e.type != _type) return false;
            if (q.isEmpty) return true;
            return e.processName.toLowerCase().contains(q) ||
                (e.commandLine?.toLowerCase().contains(q) ?? false) ||
                (e.dnsQuery?.toLowerCase().contains(q) ?? false) ||
                (e.remoteAddress?.toLowerCase().contains(q) ?? false);
          }).toList();
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No events yet',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final e = list[i];
              final ts = DateTime.tryParse(e.timestamp);
              final tsText = ts != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(ts.toLocal()) : e.timestamp;
              return Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
                child: ListTile(
                  leading: Icon(Icons.circle, size: 12, color: _colorFor(e, scheme)),
                  title: Text('${e.type} · ${e.processName}'),
                  subtitle: Text(tsText, style: theme.textTheme.bodySmall),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (c) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            Text('PID ${e.pid}', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            SelectableText(e.rawXml),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
