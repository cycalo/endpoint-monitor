import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/events_bloc.dart';

class ProcessDetailScreen extends StatelessWidget {
  const ProcessDetailScreen({super.key, required this.pid});

  final int pid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text('PID $pid'),
      ),
      body: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          final items = state.items.where((e) => e.pid == pid).toList();
          final cs = Theme.of(context).colorScheme;
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No Sysmon events for this PID yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final e = items[i];
              return Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
                child: ListTile(
                  title: Text(e.type),
                  subtitle: Text(e.timestamp),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
