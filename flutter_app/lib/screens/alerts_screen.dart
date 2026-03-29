import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/alerts_bloc.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, this.typeFilter});

  /// When set, only alerts matching this type are listed (e.g. `flagged_process`).
  final String? typeFilter;

  Color _sev(String s, ColorScheme scheme) {
    return switch (s) {
      'high' => scheme.error,
      'medium' => scheme.secondaryContainer,
      _ => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: BlocBuilder<AlertsBloc, AlertsState>(
        builder: (context, state) {
          final items = typeFilter == null || typeFilter!.isEmpty
              ? state.items
              : state.items.where((a) => a.type == typeFilter).toList();
          if (items.isEmpty) {
            return Center(
              child: Text(
                typeFilter != null ? 'No matching alerts' : 'No alerts yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final a = items[i];
              final acked = state.acked.contains(a.id);
              return Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                  side: BorderSide(color: EmDesign.ghostLine(scheme), width: 1),
                ),
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: _sev(a.severity, scheme)),
                  title: Text(a.message),
                  subtitle: Text('${a.severity} · ${a.type} · ${a.timestamp}'),
                  trailing: acked
                      ? Icon(Icons.check_circle_outline_rounded, color: scheme.tertiary)
                      : IconButton(
                          icon: const Icon(Icons.done_rounded),
                          onPressed: () => context.read<AlertsBloc>().acknowledge(a.id),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
