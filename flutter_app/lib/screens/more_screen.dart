import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/alerts_bloc.dart';
import '../bloc/connection_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          BlocBuilder<SystemInfoBloc, SystemInfoState>(
            builder: (context, si) {
              return _EndpointIdentityStrip(
                scheme: scheme,
                info: si.info,
              );
            },
          ),
          Column(
            children: [
              _MoreMenuRow(
                icon: Icons.history_rounded,
                iconColor: scheme.primary,
                title: 'Browser history',
                subtitle: 'View endpoint web activity',
                showDivider: true,
                onTap: () => context.pushNamed('browser'),
              ),
              BlocBuilder<AlertsBloc, AlertsState>(
                builder: (context, alerts) {
                  final softwareNewCount = alerts.items
                      .where((a) =>
                          !alerts.acked.contains(a.id) &&
                          a.type == AlertsBloc.softwareInstallDetectedType)
                      .length;
                  return _MoreMenuRow(
                    icon: Icons.apps_rounded,
                    iconColor: scheme.primary,
                    title: 'Installed software',
                    subtitle: softwareNewCount > 0
                        ? '$softwareNewCount new install alert${softwareNewCount == 1 ? '' : 's'} detected'
                        : 'Manage applications and versions',
                    subtitleIsAlert: softwareNewCount > 0,
                    badge: softwareNewCount > 0 ? '$softwareNewCount' : null,
                    showDivider: true,
                    onTap: () => context.pushNamed('software'),
                  );
                },
              ),
              BlocBuilder<AlertsBloc, AlertsState>(
                builder: (context, alerts) {
                  final n = alerts.items
                      .where((a) => !alerts.acked.contains(a.id))
                      .length;
                  return _MoreMenuRow(
                    icon: Icons.notifications_active_outlined,
                    iconColor: scheme.error,
                    title: 'Alerts',
                    subtitle: n > 0
                        ? '$n unread notification${n == 1 ? '' : 's'}'
                        : 'Thresholds and notifications',
                    subtitleIsAlert: n > 0,
                    badge: n > 0 ? '$n' : null,
                    showDivider: true,
                    onTap: () => context.pushNamed('alerts'),
                  );
                },
              ),
              _MoreMenuRow(
                icon: Icons.shield_outlined,
                iconColor: scheme.tertiary,
                title: 'Firewall',
                subtitle: 'Network security and rule sets',
                showDivider: true,
                onTap: () => context.pushNamed('firewall'),
              ),
              _MoreMenuRow(
                icon: Icons.computer_rounded,
                iconColor: scheme.primary,
                title: 'Controls',
                subtitle: 'Remote system controls',
                showDivider: true,
                onTap: () => context.pushNamed('controls'),
              ),
              _MoreMenuRow(
                icon: Icons.visibility_outlined,
                iconColor: scheme.primary,
                title: 'Watchlist',
                subtitle: 'Monitor priority endpoints',
                showDivider: true,
                onTap: () => context.pushNamed('watchlist'),
              ),
              _MoreMenuRow(
                icon: Icons.settings_outlined,
                iconColor: scheme.onSurfaceVariant,
                title: 'Settings',
                subtitle: 'HTTP base, tokens, PIN',
                showDivider: false,
                onTap: () => context.pushNamed('settings'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                backgroundColor: scheme.surfaceContainerHighest,
                side: BorderSide(
                  color: scheme.error.withValues(alpha: 0.22),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                ),
              ),
              onPressed: () {
                context
                    .read<ConnectionBloc>()
                    .add(const ConnectionDisconnectRequested());
                context.goNamed('connect');
              },
              icon: Icon(Icons.logout_rounded, size: 20, color: scheme.error),
              label: Text(
                'Sign out',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointIdentityStrip extends StatelessWidget {
  const _EndpointIdentityStrip({
    required this.scheme,
    required this.info,
  });

  final ColorScheme scheme;
  final SystemInfo? info;

  static String _orDash(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? '—' : t;
  }

  String _osLine(SystemInfo i) {
    final base = i.osDisplayLine.trim();
    final arch = i.osArchitecture.trim();
    if (base.isEmpty && arch.isEmpty) return '—';
    if (base.isEmpty) return arch;
    if (arch.isEmpty) return base;
    return '$base ($arch)';
  }

  @override
  Widget build(BuildContext context) {
    final i = info;
    final host = i != null ? _orDash(i.systemName) : '—';
    final ip = i != null ? _orDash(i.primaryNetworkIpv4) : '—';
    final os = i != null ? _osLine(i) : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONNECTED ENDPOINT',
            style: EmDesign.labelCaps(context, scheme),
          ),
          const SizedBox(height: 10),
          Text(
            host,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.35,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _IdentityLine(
            scheme: scheme,
            label: 'IP address',
            value: ip,
          ),
          const SizedBox(height: 10),
          _IdentityLine(
            scheme: scheme,
            label: 'OS version',
            value: os,
          ),
        ],
      ),
    );
  }
}

class _IdentityLine extends StatelessWidget {
  const _IdentityLine({
    required this.scheme,
    required this.label,
    required this.value,
  });

  final ColorScheme scheme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreMenuRow extends StatelessWidget {
  const _MoreMenuRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.showDivider,
    this.subtitleIsAlert = false,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;
  final bool subtitleIsAlert;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            subtitleIsAlert ? FontWeight.w600 : FontWeight.w500,
                        color: subtitleIsAlert
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );

    if (!showDivider) return tile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        Divider(
          height: 1,
          thickness: 1,
          indent: 72,
          endIndent: 0,
          color: scheme.outlineVariant.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}
