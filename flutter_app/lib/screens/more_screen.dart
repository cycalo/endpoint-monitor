import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/alerts_bloc.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text(
            'Operations & security',
            style: EmDesign.labelCaps(context, scheme),
          ),
          const SizedBox(height: 12),
          _NavGroup(
            children: [
              _MoreTile(
                icon: Icons.history_rounded,
                title: 'Browser history',
                subtitle: 'Visited hosts and timelines',
                onTap: () => context.pushNamed('browser'),
              ),
              _MoreTile(
                icon: Icons.apps_rounded,
                title: 'Installed software',
                subtitle: 'Inventory and versions',
                onTap: () => context.pushNamed('software'),
              ),
              BlocBuilder<AlertsBloc, AlertsState>(
                builder: (context, alerts) {
                  final n = alerts.items.where((a) => !alerts.acked.contains(a.id)).length;
                  return _MoreTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Alerts',
                    subtitle: 'Thresholds and notifications',
                    badge: n > 0 ? '$n' : null,
                    onTap: () => context.pushNamed('alerts'),
                  );
                },
              ),
              _MoreTile(
                icon: Icons.shield_outlined,
                title: 'Firewall rules',
                subtitle: 'Allow and block lists',
                onTap: () => context.pushNamed('firewall'),
              ),
              _MoreTile(
                icon: Icons.visibility_outlined,
                title: 'Watchlist',
                subtitle: 'Processes and indicators',
                onTap: () => context.pushNamed('watchlist'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Configuration',
            style: EmDesign.labelCaps(context, scheme),
          ),
          const SizedBox(height: 12),
          _NavGroup(
            children: [
              _MoreTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'HTTP base, tokens, PIN',
                onTap: () => context.pushNamed('settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavGroup extends StatelessWidget {
  const _NavGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        border: EmDesign.ghostBorder(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: EmDesign.ghostLine(scheme)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: scheme.outlineVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
