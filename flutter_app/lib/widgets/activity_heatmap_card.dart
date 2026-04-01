import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../bloc/activity_heatmap_bloc.dart';
import '../theme/em_design_system.dart';

const double _kCellHeight = 32;
const double _kGap = 2;
const int _kBuckets = 24;

Color _heatmapCellColor(
  BuildContext context,
  int activityLevel,
  bool hasAlert,
) {
  final scheme = Theme.of(context).colorScheme;
  if (hasAlert) return const Color(0xFFE53935);
  if (activityLevel <= 0) {
    return scheme.surfaceContainerHighest.withValues(alpha: 0.35);
  }
  if (activityLevel <= 3) {
    return const Color(0xFF006064).withValues(alpha: 0.42);
  }
  if (activityLevel <= 6) {
    return const Color(0xFF00838F);
  }
  if (activityLevel <= 9) {
    return const Color(0xFF00ACC1);
  }
  return const Color(0xFF84FFFF);
}

Color _heatmapBorderColor(
  BuildContext context,
  int activityLevel,
  bool hasAlert,
) {
  final scheme = Theme.of(context).colorScheme;
  if (hasAlert) return const Color(0xFFFF8A80).withValues(alpha: 0.5);
  if (activityLevel <= 0) {
    return scheme.outlineVariant.withValues(alpha: 0.28);
  }
  return Colors.transparent;
}

class ActivityHeatmapCard extends StatefulWidget {
  const ActivityHeatmapCard({
    super.key,
    required this.loading,
    required this.buckets,
    required this.onRefresh,
  });

  final bool loading;
  final List<ActivityHeatmapBucket> buckets;
  final VoidCallback onRefresh;

  @override
  State<ActivityHeatmapCard> createState() => _ActivityHeatmapCardState();
}

class _ActivityHeatmapCardState extends State<ActivityHeatmapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  OverlayEntry? _tooltipEntry;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _removeTooltip();
    _pulseController.dispose();
    super.dispose();
  }

  void _removeTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  bool get _isEmptyData {
    if (widget.loading) return false;
    if (widget.buckets.isEmpty) return true;
    return widget.buckets.every(
      (b) => b.activityLevel == 0 && !b.hasAlert,
    );
  }

  void _showCellTooltip(
    BuildContext context,
    Offset globalTap,
    ActivityHeatmapBucket bucket,
  ) {
    _removeTooltip();
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final startUtc = DateTime.tryParse(bucket.hourStartUtcIso)?.toUtc();
    if (startUtc == null) return;
    final startLocal = startUtc.toLocal();
    final hh = startLocal.hour.toString().padLeft(2, '0');
    final rangeLabel =
        '$hh:00 — $hh:59 · Activity level ${bucket.activityLevel}/10';

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    final tapLocal = overlayBox.globalToLocal(globalTap);
    final mq = MediaQuery.of(context);
    const tw = 200.0;
    var left = tapLocal.dx - tw / 2;
    left = left.clamp(8.0, mq.size.width - tw - 8);
    final top = (tapLocal.dy - 68).clamp(8.0, mq.size.height - 80);

    _tooltipEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: top,
        width: tw,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: scheme.inverseSurface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rangeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onInverseSurface,
                    height: 1.35,
                  ),
                ),
                if (bucket.hasAlert) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⚠ Alert detected this hour',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFFF8A80),
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(_tooltipEntry!);
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _removeTooltip();
    });
  }

  void _onCellTap(
    TapDownDetails details,
    ActivityHeatmapBucket bucket,
  ) {
    if (bucket.hourStartUtcIso.isEmpty) return;
    _showCellTooltip(context, details.globalPosition, bucket);
    if (bucket.hasAlert) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _removeTooltip();
        context.go(
          '/events?hour=${Uri.encodeComponent(bucket.hourStartUtcIso)}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        border: EmDesign.ghostBorder(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '24H ACTIVITY',
                  style: EmDesign.labelCaps(context, scheme),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: widget.onRefresh,
                icon: Icon(Icons.refresh_rounded, color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cellW = (w - _kGap * (_kBuckets - 1)) / _kBuckets;
              if (widget.loading) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShimmerHeatmapRow(cellWidth: cellW),
                    const SizedBox(height: 4),
                    _labelRowPlaceholder(theme, scheme, cellW),
                  ],
                );
              }
              final buckets = widget.buckets.length >= _kBuckets
                  ? widget.buckets.sublist(0, _kBuckets)
                  : List<ActivityHeatmapBucket>.generate(
                      _kBuckets,
                      (i) => i < widget.buckets.length
                          ? widget.buckets[i]
                          : ActivityHeatmapBucket(
                              hourIndex: i,
                              hourStartUtcIso: '',
                              activityLevel: 0,
                              hasAlert: false,
                            ),
                    );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(_kBuckets, (i) {
                      final b = buckets[i];
                      final fill = _isEmptyData
                          ? _HeatmapCellPlaceholder(width: cellW)
                          : _HeatmapCell(
                              width: cellW,
                              height: _kCellHeight,
                              activityLevel: b.activityLevel,
                              hasAlert: b.hasAlert,
                              pulse: _pulseController,
                              onTapDown: (d) => _onCellTap(d, b),
                            );
                      return Padding(
                        padding:
                            EdgeInsets.only(right: i < _kBuckets - 1 ? _kGap : 0),
                        child: fill,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  if (_isEmptyData)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'No activity recorded yet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                    )
                  else
                    _HourLabelsRow(
                      buckets: buckets,
                      cellWidth: cellW,
                      scheme: scheme,
                      theme: theme,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _labelRowPlaceholder(ThemeData theme, ColorScheme scheme, double cellW) {
    return SizedBox(
      height: 14,
      child: Row(
        children: List.generate(_kBuckets, (i) {
          final show = i % 4 == 0;
          return Padding(
            padding: EdgeInsets.only(right: i < _kBuckets - 1 ? _kGap : 0),
            child: SizedBox(
              width: cellW,
              child: show
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }),
      ),
    );
  }
}

class _HourLabelsRow extends StatelessWidget {
  const _HourLabelsRow({
    required this.buckets,
    required this.cellWidth,
    required this.scheme,
    required this.theme,
  });

  final List<ActivityHeatmapBucket> buckets;
  final double cellWidth;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_kBuckets, (i) {
          final show = i % 4 == 0;
          String label = '';
          if (show && i < buckets.length) {
            final iso = buckets[i].hourStartUtcIso;
            final t = DateTime.tryParse(iso)?.toLocal();
            if (t != null) {
              label = '${t.hour.toString().padLeft(2, '0')}h';
            }
          }
          return Padding(
            padding: EdgeInsets.only(right: i < _kBuckets - 1 ? _kGap : 0),
            child: SizedBox(
              width: cellWidth,
              child: show && label.isNotEmpty
                  ? Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: scheme.outline,
                        height: 1,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }),
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({
    required this.width,
    required this.height,
    required this.activityLevel,
    required this.hasAlert,
    required this.pulse,
    required this.onTapDown,
  });

  final double width;
  final double height;
  final int activityLevel;
  final bool hasAlert;
  final AnimationController pulse;
  final void Function(TapDownDetails details) onTapDown;

  @override
  Widget build(BuildContext context) {
    final fill = _heatmapCellColor(context, activityLevel, hasAlert);
    final border = _heatmapBorderColor(context, activityLevel, hasAlert);

    Widget cell = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: activityLevel <= 0 ? 1 : 0),
      ),
    );

    if (hasAlert) {
      cell = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = 0.88 + pulse.value * 0.12;
          return Opacity(opacity: t, child: child);
        },
        child: cell,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: onTapDown,
        borderRadius: BorderRadius.circular(4),
        splashColor: Colors.white24,
        child: cell,
      ),
    );
  }
}

class _HeatmapCellPlaceholder extends StatelessWidget {
  const _HeatmapCellPlaceholder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: _kCellHeight,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _ShimmerHeatmapRow extends StatefulWidget {
  const _ShimmerHeatmapRow({required this.cellWidth});

  final double cellWidth;

  @override
  State<_ShimmerHeatmapRow> createState() => _ShimmerHeatmapRowState();
}

class _ShimmerHeatmapRowState extends State<_ShimmerHeatmapRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.2 + t * 2.4, 0),
              end: const Alignment(1.2, 0),
              colors: [
                scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                scheme.outlineVariant.withValues(alpha: 0.45),
                scheme.surfaceContainerHighest.withValues(alpha: 0.25),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Row(
        children: List.generate(_kBuckets, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i < _kBuckets - 1 ? _kGap : 0),
            child: _HeatmapCellPlaceholder(width: widget.cellWidth),
          );
        }),
      ),
    );
  }
}
