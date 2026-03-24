import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            'TOOLS',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deep inspection and policy surfaces.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _MoreTile(
            icon: Icons.public_rounded,
            title: 'Browser history',
            subtitle: 'Visited hosts and timelines',
            onTap: () => context.pushNamed('browser'),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.apps_rounded,
            title: 'Installed software',
            subtitle: 'Inventory and versions',
            onTap: () => context.pushNamed('software'),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.notifications_active_outlined,
            title: 'Alerts',
            subtitle: 'Thresholds and notifications',
            onTap: () => context.pushNamed('alerts'),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.shield_outlined,
            title: 'Firewall rules',
            subtitle: 'Allow and block lists',
            onTap: () => context.pushNamed('firewall'),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.flag_outlined,
            title: 'Watchlist',
            subtitle: 'Processes and indicators',
            onTap: () => context.pushNamed('watchlist'),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'HTTP base, tokens, PIN',
            onTap: () => context.pushNamed('settings'),
          ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
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
              Icon(Icons.chevron_right_rounded, color: scheme.outlineVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
