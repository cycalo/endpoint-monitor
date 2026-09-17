import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../connect/connect_guide.dart';
import '../connect/connect_path.dart';
import '../theme/em_design_system.dart';

/// First connect screen: pick Local Wi-Fi or Tailscale.
class ConnectChooser extends StatelessWidget {
  const ConnectChooser({
    super.key,
    required this.onPathSelected,
    this.savedHost,
    this.savedPath,
    this.onContinueSaved,
  });

  final ValueChanged<ConnectPath> onPathSelected;
  final String? savedHost;
  final ConnectPath? savedPath;
  final VoidCallback? onContinueSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          kConnectChooserTitle,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          kConnectChooserSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (savedHost != null &&
            savedHost!.isNotEmpty &&
            onContinueSaved != null) ...[
          const SizedBox(height: 18),
          Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onContinueSaved,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: EmDesign.ghostBorder(scheme),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        continueToSavedLabel(savedHost!),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: scheme.outline),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        _ConnectPathCard(
          path: ConnectPath.wifi,
          icon: Icons.wifi_rounded,
          onTap: () => onPathSelected(ConnectPath.wifi),
        ),
        const SizedBox(height: 12),
        _ConnectPathCard(
          path: ConnectPath.tailscale,
          icon: Icons.public_rounded,
          onTap: () => onPathSelected(ConnectPath.tailscale),
        ),
        const SizedBox(height: 20),
        const _WindowsServiceDownloadRow(),
      ],
    );
  }
}

class _WindowsServiceDownloadRow extends StatelessWidget {
  const _WindowsServiceDownloadRow();

  Future<void> _openReleases(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(kWindowsServiceReleasesUri),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open download page')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(EmDesign.radiusLg),
      child: InkWell(
        onTap: () => _openReleases(context),
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: EmDesign.cardShell(
            scheme,
            color: scheme.surfaceContainerLow,
          ),
          child: Row(
            children: [
              Icon(Icons.download_rounded, color: scheme.tertiary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kWindowsServiceDownloadTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      kWindowsServiceDownloadSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectPathCard extends StatelessWidget {
  const _ConnectPathCard({
    required this.path,
    required this.icon,
    required this.onTap,
  });

  final ConnectPath path;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(EmDesign.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: EmDesign.cardShell(scheme, color: scheme.surfaceContainer),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                  border: EmDesign.ghostBorder(scheme),
                ),
                child: Icon(icon, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connectPathCardTitle(path),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connectPathCardSubtitle(path),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
