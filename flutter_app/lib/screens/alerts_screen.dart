import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/alerts_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../utils/relative_time.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, this.typeFilter});

  /// When set, only alerts matching this type are listed (e.g. `flagged_process`).
  final String? typeFilter;

  Color _sevColor(String s, ColorScheme scheme) {
    return switch (s) {
      'high' => scheme.error,
      'medium' => scheme.tertiary,
      _ => scheme.onSurfaceVariant,
    };
  }

  String _typeLabel(String type) {
    return switch (type) {
      AlertsBloc.softwareInstallDetectedType => 'Software install',
      'flagged_process' => 'Flagged process',
      'threat_intel_connection' => 'Threat intel',
      'suspicious_connection' => 'Suspicious connection',
      _ => type.replaceAll('_', ' '),
    };
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      AlertsBloc.softwareInstallDetectedType => Icons.apps_rounded,
      'flagged_process' => Icons.flag_rounded,
      'threat_intel_connection' => Icons.public_off_rounded,
      'suspicious_connection' => Icons.travel_explore_rounded,
      _ => Icons.warning_amber_rounded,
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
          final unacked =
              items.where((a) => !state.acked.contains(a.id)).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              EmDesign.spaceMd,
              8,
              EmDesign.spaceMd,
              EmDesign.scrollBottomInset,
            ),
            children: [
              EmPageIntro(
                title: 'Alerts',
                subtitle: typeFilter != null
                    ? 'Filtered alert stream from the endpoint.'
                    : 'Threshold breaches and watchlist notifications.',
                padding: const EdgeInsets.only(bottom: 8),
                trailing: items.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: unacked > 0
                              ? scheme.errorContainer.withValues(alpha: 0.35)
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                          border: EmDesign.ghostBorder(scheme),
                        ),
                        child: Text(
                          unacked > 0 ? '$unacked unread' : '${items.length} total',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: unacked > 0
                                ? scheme.onErrorContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : null,
              ),
              if (items.isEmpty)
                EmEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: typeFilter != null
                      ? 'No matching alerts'
                      : 'All clear',
                  message: typeFilter != null
                      ? 'No alerts match this filter type right now.'
                      : 'New alerts will appear here when rules trigger on the endpoint.',
                )
              else
                ...items.asMap().entries.map((e) {
                  final alert = e.value;
                  return Padding(
                    padding: EdgeInsets.only(top: e.key == 0 ? 4 : EmDesign.spaceSm),
                    child: _AlertTile(
                      alert: alert,
                      acked: state.acked.contains(alert.id),
                      scheme: scheme,
                      typeIcon: _typeIcon(alert.type),
                      typeLabel: _typeLabel(alert.type),
                      severityColor: _sevColor(alert.severity, scheme),
                      onAck: () =>
                          context.read<AlertsBloc>().acknowledge(alert.id),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.acked,
    required this.scheme,
    required this.typeIcon,
    required this.typeLabel,
    required this.severityColor,
    required this.onAck,
  });

  final Alert alert;
  final bool acked;
  final ColorScheme scheme;
  final IconData typeIcon;
  final String typeLabel;
  final Color severityColor;
  final VoidCallback onAck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relative = formatRelativeSinceUtcIso(alert.timestamp);
    final isHigh = alert.severity == 'high';

    return Material(
      color: acked ? scheme.surfaceContainerLow : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        side: BorderSide(
          color: acked
              ? EmDesign.ghostLine(scheme)
              : severityColor.withValues(alpha: isHigh ? 0.35 : 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        onTap: acked ? null : onAck,
        child: Padding(
          padding: const EdgeInsets.all(EmDesign.spaceMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                  border: Border.all(
                    color: severityColor.withValues(alpha: 0.25),
                  ),
                  boxShadow: isHigh && !acked
                      ? [
                          BoxShadow(
                            color: severityColor.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Icon(typeIcon, color: severityColor, size: 22),
              ),
              const SizedBox(width: EmDesign.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          typeLabel.toUpperCase(),
                          style: EmDesign.labelCaps(context, scheme),
                        ),
                        const Spacer(),
                        Text(
                          relative,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: EmDesign.spaceXs),
                    Text(
                      alert.message,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: EmDesign.spaceXs),
                    Row(
                      children: [
                        _SeverityChip(
                          label: alert.severity,
                          color: severityColor,
                          scheme: scheme,
                        ),
                        if (acked) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Acknowledged',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!acked)
                IconButton(
                  tooltip: 'Acknowledge',
                  onPressed: onAck,
                  icon: Icon(
                    Icons.done_rounded,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({
    required this.label,
    required this.color,
    required this.scheme,
  });

  final String label;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EmDesign.radiusSm),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}
