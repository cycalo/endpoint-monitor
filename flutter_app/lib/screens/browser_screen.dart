import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/browser_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BrowserBloc>().request('all');
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _requestKeyForTab(int i) => switch (i) {
        0 => 'all',
        1 => 'chrome',
        2 => 'edge',
        _ => 'firefox',
      };

  void _requestForCurrentTab() =>
      context.read<BrowserBloc>().request(_requestKeyForTab(_tabs.index));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Material(
            color: scheme.surfaceContainerLow,
            child: TabBar(
              controller: _tabs,
              onTap: (i) => context
                  .read<BrowserBloc>()
                  .request(_requestKeyForTab(i)),
              indicatorColor: scheme.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Chrome'),
                Tab(text: 'Edge'),
                Tab(text: 'Firefox'),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<BrowserBloc, BrowserState>(
        builder: (context, state) {
          if (state.loading && state.items.isEmpty) {
            return const EmListSkeleton();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: EmPageIntro(
                  title: 'Browser history',
                  subtitle: 'Recent visits from Chrome, Edge, and Firefox profiles.',
                  padding: EdgeInsets.zero,
                  trailing: !state.loading
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${state.items.length} entries',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.tertiary,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: state.items.isEmpty
                    ? EmEmptyState(
                        icon: Icons.history_toggle_off_rounded,
                        title: 'No history for this profile',
                        message:
                            'Pull to refresh or switch browser tabs above.',
                      )
                    : RefreshIndicator(
                        color: scheme.primary,
                        onRefresh: () async {
                          _requestForCurrentTab();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 400),
                          );
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: state.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            return _HistoryCard(
                              entry: state.items[i],
                              scheme: scheme,
                              index: i,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.scheme,
    required this.index,
  });

  final BrowserHistoryEntry entry;
  final ColorScheme scheme;
  final int index;

  static String _displayHost(String url) {
    final t = url.trim();
    if (t.isEmpty) return '—';
    try {
      final u = Uri.parse(t);
      if (u.host.isNotEmpty) return u.host;
      return t.length > 48 ? '${t.substring(0, 48)}…' : t;
    } catch (_) {
      return t.length > 48 ? '${t.substring(0, 48)}…' : t;
    }
  }

  static (IconData, Color) _browserVisuals(String browser, ColorScheme scheme) {
    final b = browser.toLowerCase();
    if (b.contains('chrome')) {
      return (Icons.public_rounded, scheme.primary);
    }
    if (b.contains('edge')) {
      return (Icons.explore_rounded, scheme.tertiary);
    }
    if (b.contains('firefox')) {
      return (Icons.whatshot_rounded, const Color(0xFFFF8F5C));
    }
    return (Icons.language_rounded, scheme.outline);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, accent) = _browserVisuals(entry.browser, scheme);
    final title = entry.title.trim().isNotEmpty
        ? entry.title.trim()
        : _displayHost(entry.url);
    final hostLine = _displayHost(entry.url);
    final bg = index.isEven
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLow;
    final browserLabel =
        entry.browser.isEmpty ? 'Browser' : entry.browser.toUpperCase();
    final timeLabel = entry.visitTime.isEmpty ? '—' : entry.visitTime;
    final visitsLabel = '${entry.visitCount}× visits';

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(EmDesign.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: accent.withValues(alpha: 0.85),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(EmDesign.radiusMd),
                        ),
                        child: Icon(icon, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hostLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: EmDesign.ghostLine(scheme),
                                ),
                              ),
                              child: Text(
                                '$browserLabel  ·  $timeLabel  ·  $visitsLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.18,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.88,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Copy URL',
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            foregroundColor: scheme.primary,
                          ),
                          onPressed: entry.url.trim().isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: entry.url.trim()),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        'URL copied',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.copy_rounded, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

