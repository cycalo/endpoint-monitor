import 'package:flutter/material.dart';

import '../theme/em_design_system.dart';
import 'em_brand_app_bar.dart';
import 'em_gradient_button.dart';

/// Shared page intro (headline + subtitle). Prefer over duplicate headers.
class EmPageIntro extends StatelessWidget {
  const EmPageIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(0, 8, 0, 16),
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
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
                  const SizedBox(height: EmDesign.spaceXs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
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

/// Inline status: loading spinner or informational icon + message.
class EmStatusPanel extends StatelessWidget {
  const EmStatusPanel({
    super.key,
    this.loading = false,
    required this.message,
    this.icon,
  });

  final bool loading;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: EmDesign.spaceMd,
        vertical: EmDesign.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        border: EmDesign.ghostBorder(scheme),
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else
            Icon(
              icon ?? Icons.info_outline_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          const SizedBox(width: EmDesign.spaceSm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered empty state with optional CTA.
class EmEmptyState extends StatelessWidget {
  const EmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vertical = compact ? EmDesign.spaceLg : EmDesign.space2xl;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: EmDesign.spaceMd,
          vertical: vertical,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 56 : 72,
                height: compact ? 56 : 72,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                  border: EmDesign.ghostBorder(scheme),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: compact ? 28 : 34,
                  color: scheme.primary.withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: compact ? EmDesign.spaceMd : EmDesign.spaceLg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: EmDesign.spaceXs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: EmDesign.spaceLg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen route error when [GoRouter] extra is missing.
class EmRouteErrorBody extends StatelessWidget {
  const EmRouteErrorBody({
    super.key,
    required this.title,
    this.message,
    required this.onBack,
  });

  final String title;
  final String? message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: EmEmptyState(
        icon: Icons.link_off_rounded,
        title: title,
        message: message ??
            'The requested item is no longer available. Go back and open it again.',
        action: EmGradientButton(
          label: 'Go back',
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }
}

/// Shimmer sweep used by skeleton placeholders.
class EmShimmer extends StatefulWidget {
  const EmShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<EmShimmer> createState() => _EmShimmerState();
}

class _EmShimmerState extends State<EmShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.2 + t * 2.4, 0),
              end: Alignment(-0.2 + t * 2.4, 0),
              colors: [
                scheme.surfaceContainer,
                scheme.surfaceContainerHigh,
                scheme.surfaceContainer,
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    this.width,
    this.radius = EmDesign.radiusMd,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Generic list loading placeholder (processes, network, events, etc.).
class EmListSkeleton extends StatelessWidget {
  const EmListSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return EmShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(height: EmDesign.spaceSm),
        itemBuilder: (_, i) {
          final wide = i % 3 != 1;
          return Container(
            padding: const EdgeInsets.all(EmDesign.spaceMd),
            decoration: EmDesign.cardShell(scheme),
            child: Row(
              children: [
                _SkeletonBox(height: 40, width: 40, radius: EmDesign.radiusSm),
                const SizedBox(width: EmDesign.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(
                        height: 14,
                        width: wide ? double.infinity : 160,
                      ),
                      const SizedBox(height: EmDesign.spaceXs),
                      _SkeletonBox(height: 10, width: wide ? 120 : 200),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dashboard metrics grid while [SystemInfo] is loading.
class EmDashboardMetricsSkeleton extends StatelessWidget {
  const EmDashboardMetricsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget card({required double h}) {
      return Container(
        height: h,
        decoration: EmDesign.cardShell(scheme),
        padding: const EdgeInsets.all(EmDesign.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(height: 10, width: 72, radius: EmDesign.radiusSm),
            const Spacer(),
            _SkeletonBox(height: 28, width: 100),
            const SizedBox(height: EmDesign.spaceXs),
            _SkeletonBox(height: 8, width: 140),
          ],
        ),
      );
    }

    return EmShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: EmDesign.spaceMd),
          Row(
            children: [
              Expanded(child: card(h: 100)),
              const SizedBox(width: EmDesign.spaceMd),
              Expanded(child: card(h: 100)),
            ],
          ),
          const SizedBox(height: EmDesign.spaceMd),
          card(h: 140),
          const SizedBox(height: EmDesign.spaceMd),
          card(h: 180),
        ],
      ),
    );
  }
}

/// Banner when showing cached data while disconnected from the live channel.
class EmStaleSnapshotBanner extends StatelessWidget {
  const EmStaleSnapshotBanner({
    super.key,
    this.cachedAt,
    this.compact = false,
  });

  final DateTime? cachedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final age = cachedAt != null
        ? _ageLabel(DateTime.now().toUtc().difference(cachedAt!.toUtc()))
        : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: EmDesign.spaceMd,
        vertical: compact ? EmDesign.spaceSm : EmDesign.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: EmDesign.spaceSm),
          Expanded(
            child: Text(
              age != null
                  ? 'Offline snapshot · last updated $age'
                  : 'Offline snapshot · reconnect for live data',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _ageLabel(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

/// Settings / grouped form section with optional unsaved indicator.
class EmSettingsSection extends StatelessWidget {
  const EmSettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.dirty = false,
    this.trailing,
  });

  final String title;
  final Widget child;
  final bool dirty;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: EmDesign.spaceXs),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: EmDesign.labelCaps(context, scheme)),
              ),
              if (dirty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'UNSAVED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(EmDesign.spaceMd),
          decoration: EmDesign.cardShell(scheme),
          child: child,
        ),
      ],
    );
  }
}

/// Collapsible list for long rule/block collections (Firewall, etc.).
class EmCollapsibleBlockList<T> extends StatefulWidget {
  const EmCollapsibleBlockList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.initialVisible = 3,
    this.empty,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int initialVisible;
  final Widget? empty;

  @override
  State<EmCollapsibleBlockList<T>> createState() =>
      _EmCollapsibleBlockListState<T>();
}

class _EmCollapsibleBlockListState<T> extends State<EmCollapsibleBlockList<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.empty ?? const SizedBox.shrink();
    }
    final showAll = _expanded || widget.items.length <= widget.initialVisible;
    final visible = showAll
        ? widget.items
        : widget.items.take(widget.initialVisible).toList();
    final hidden = widget.items.length - visible.length;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: EmDesign.spaceSm),
            child: widget.itemBuilder(context, item),
          ),
        if (!showAll && hidden > 0)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = true),
            icon: Icon(Icons.unfold_more_rounded, color: scheme.primary),
            label: Text('Show $hidden more'),
          )
        else if (_expanded && widget.items.length > widget.initialVisible)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = false),
            icon: Icon(Icons.unfold_less_rounded, color: scheme.primary),
            label: const Text('Show less'),
          ),
      ],
    );
  }
}
