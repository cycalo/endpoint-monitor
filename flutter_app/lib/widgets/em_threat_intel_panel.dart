import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/threat_intel_bloc.dart';
import '../theme/em_design_system.dart';
import '../utils/relative_time.dart';

/// Threat feed status and manual refresh — belongs on Network, not Settings.
class EmThreatIntelPanel extends StatelessWidget {
  const EmThreatIntelPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return BlocBuilder<ThreatIntelBloc, ThreatIntelState>(
      builder: (context, ti) {
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: EmDesign.cardShell(scheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.gpp_maybe_outlined,
                      size: compact ? 20 : 22, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'THREAT INTEL',
                      style: EmDesign.labelCaps(context, scheme),
                    ),
                  ),
                  if (ti.loading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${ti.entryCount} known threat IPs monitored',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  'Connections to these IPs trigger high severity alerts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              if (ti.feeds.isNotEmpty && !compact) ...[
                const SizedBox(height: 8),
                for (final f in ti.feeds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${f.name} · ${f.count} IPs',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
              if (ti.lastError != null && ti.lastError!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  ti.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              if (formatRelativeSinceUtcIso(ti.lastRunUtc).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Last updated: ${formatRelativeSinceUtcIso(ti.lastRunUtc)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: ti.loading
                    ? null
                    : () =>
                        context.read<ThreatIntelBloc>().requestRefreshFeeds(),
                child: Text(ti.loading ? 'Updating…' : 'Update feeds now'),
              ),
            ],
          ),
        );
      },
    );
  }
}
