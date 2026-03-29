import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/connection_bloc.dart';

/// Normalized host for status display (strips scheme/path/port).
String emDisplayConnectionHost(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  var h = raw
      .replaceFirst(RegExp(r'^wss?://'), '')
      .replaceFirst(RegExp(r'^https?://'), '');
  final slash = h.indexOf('/');
  if (slash >= 0) h = h.substring(0, slash);
  final colon = h.indexOf(':');
  if (colon >= 0) h = h.substring(0, colon);
  return h.isEmpty ? '—' : h;
}

class _EmConnectionStatus extends StatelessWidget {
  const _EmConnectionStatus();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dataStyle =
        GoogleFonts.inter(fontSize: 11, color: scheme.onSurfaceVariant);

    return LayoutBuilder(
      builder: (context, constraints) {
        return BlocBuilder<ConnectionBloc, EmConnectionState>(
          builder: (context, c) {
            if (!c.isConnected) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'OFFLINE',
                  style:
                      dataStyle.copyWith(fontSize: 10, color: scheme.outline),
                ),
              );
            }
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
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
                        color: scheme.tertiary,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.tertiary.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'CONNECTED',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dataStyle.copyWith(
                          fontSize: 10,
                          color: scheme.tertiary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Shell header: monitor mark, live connection pill, optional trailing actions, link icon.
class EmBrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmBrandAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.bottom,
  });

  /// Optional leading control (e.g. back on pushed routes).
  final Widget? leading;

  /// Shown after the monitor icon (e.g. "Endpoint Monitor" on tab screens).
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  Future<void> _scrollToTop(BuildContext context) async {
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) return;
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      bottom: bottom,
      leading: leading,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 12,
      title: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Tap to scroll to top',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _scrollToTop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.monitor_heart_rounded,
                          color: scheme.primary, size: 26),
                      const SizedBox(width: 8),
                      if (title != null) ...[
                        title!,
                        const SizedBox(width: 8),
                      ],
                      const Expanded(child: _EmConnectionStatus()),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (actions != null) ...actions!,
          IconButton(
            tooltip: 'Scroll to top',
            onPressed: () => _scrollToTop(context),
            icon: Icon(
              Icons.vertical_align_top_rounded,
              color: scheme.primary,
            ),
          ),
          BlocBuilder<ConnectionBloc, EmConnectionState>(
            builder: (context, c) {
              return IconButton(
                tooltip: c.isConnected ? 'Disconnect' : 'Connect',
                onPressed: () {
                  if (c.isConnected) {
                    context
                        .read<ConnectionBloc>()
                        .add(const ConnectionDisconnectRequested());
                  } else {
                    context.goNamed('connect');
                  }
                },
                icon: Icon(
                  c.isConnected ? Icons.link_off_rounded : Icons.link_rounded,
                  color: scheme.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Page title block: editorial headline + optional subtitle (Connect / Processes style).
class EmPageHeader extends StatelessWidget {
  const EmPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
