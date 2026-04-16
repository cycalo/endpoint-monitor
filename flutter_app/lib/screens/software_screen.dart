import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/alerts_bloc.dart';
import '../bloc/software_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../utils/software_display.dart';
import '../widgets/em_brand_app_bar.dart';

enum _SoftwareSort {
  nameAZ,
  dateNewest,
  vendorAZ,
}

class SoftwareScreen extends StatefulWidget {
  const SoftwareScreen({super.key});

  @override
  State<SoftwareScreen> createState() => _SoftwareScreenState();
}

class _SoftwareScreenState extends State<SoftwareScreen> {
  final _search = TextEditingController();
  _SoftwareSort _sort = _SoftwareSort.nameAZ;

  String _sortMenuLabel(_SoftwareSort s) {
    switch (s) {
      case _SoftwareSort.nameAZ:
        return 'Name A-Z';
      case _SoftwareSort.dateNewest:
        return 'Install date';
      case _SoftwareSort.vendorAZ:
        return 'Vendor';
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SoftwareBloc>().request();
    });
  }

  List<InstalledSoftwareItem> _filteredAndSorted(List<InstalledSoftwareItem> raw) {
    final q = _search.text.trim().toLowerCase();
    var list = raw.where((s) => isValidSoftwareName(s.name)).where((s) {
      if (q.isEmpty) return true;
      final name = s.name.toLowerCase();
      final vendor = s.vendor.toLowerCase();
      return name.contains(q) || vendor.contains(q);
    }).toList();

    int cmpName(InstalledSoftwareItem a, InstalledSoftwareItem b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    int cmpVendor(InstalledSoftwareItem a, InstalledSoftwareItem b) =>
        a.vendor.toLowerCase().compareTo(b.vendor.toLowerCase());

    switch (_sort) {
      case _SoftwareSort.nameAZ:
        list.sort(cmpName);
        break;
      case _SoftwareSort.vendorAZ:
        list.sort((a, b) {
          final v = cmpVendor(a, b);
          if (v != 0) return v;
          return cmpName(a, b);
        });
        break;
      case _SoftwareSort.dateNewest:
        list.sort((a, b) {
          final da = tryParseInstallDate(a.installDate);
          final db = tryParseInstallDate(b.installDate);
          if (da == null && db == null) return cmpName(a, b);
          if (da == null) return 1;
          if (db == null) return -1;
          final c = db.compareTo(da);
          if (c != 0) return c;
          return cmpName(a, b);
        });
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        title: Text(
          'Software',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: scheme.primary,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                hintText: 'Search name or vendor...',
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(EmDesign.radiusLg),
                  borderSide: BorderSide(color: scheme.tertiary, width: 1.4),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  'SORT',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: PopupMenuButton<_SoftwareSort>(
                      tooltip: 'Sort',
                      offset: const Offset(0, 40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sortMenuLabel(_sort),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.filter_list_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                      onSelected: (v) => setState(() => _sort = v),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _SoftwareSort.nameAZ,
                          child: Text('Name A-Z', style: theme.textTheme.bodyMedium),
                        ),
                        PopupMenuItem(
                          value: _SoftwareSort.dateNewest,
                          child: Text(
                            'Install date (newest first)',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        PopupMenuItem(
                          value: _SoftwareSort.vendorAZ,
                          child: Text('Vendor', style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<AlertsBloc, AlertsState>(
            builder: (context, alerts) {
              final softwareAlerts = alerts.items
                  .where((a) =>
                      a.type == AlertsBloc.softwareInstallDetectedType &&
                      !alerts.acked.contains(a.id))
                  .toList();
              final n = softwareAlerts.length;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                    border: Border.all(
                      color: scheme.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_task_rounded,
                        size: 18,
                        color: scheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$n new software install alert${n == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context
                            .push('/alerts?type=${AlertsBloc.softwareInstallDetectedType}'),
                        child: const Text('View alerts'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          BlocBuilder<SoftwareBloc, SoftwareState>(
            builder: (context, state) {
              if (state.loading && state.items.isEmpty) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final list = _filteredAndSorted(state.items);
              final totalValid =
                  state.items.where((s) => isValidSoftwareName(s.name)).length;

              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$totalValid applications installed',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (!state.loading)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.tertiary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: scheme.tertiary.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                '${list.length} shown',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.tertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? _EmptyState(hasAnyData: state.items.isNotEmpty)
                          : ListView.separated(
                              primary: true,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: list.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                return _SoftwareCard(
                                  item: list[i],
                                  scheme: scheme,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAnyData});

  final bool hasAnyData;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasAnyData ? Icons.search_off_rounded : Icons.apps_outlined,
              size: 72,
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 20),
            Text(
              hasAnyData ? 'No matching software' : 'No software loaded yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hasAnyData
                  ? 'Try a different search or clear the filter.'
                  : 'Pull to refresh after connecting, or open this screen again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftwareCard extends StatelessWidget {
  const _SoftwareCard({
    required this.item,
    required this.scheme,
  });

  final InstalledSoftwareItem item;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final name = item.name.trim().isEmpty ? '—' : item.name.trim();
    final vendorVersion = buildSoftwareCardVendorVersionLine(item);
    final dateAndSizeLine = formatSoftwareDateAndSizeLine(
      normalizeInstallDateDisplay(item.installDate),
      item.installSizeKb,
    );
    final recent = isInstalledWithinLastDays(item.installDate, 30);

    return Material(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        side: BorderSide(color: EmDesign.ghostLine(scheme)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        onTap: () => context.push('/software/detail', extra: item),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(EmDesign.radiusLg),
                  bottomLeft: Radius.circular(EmDesign.radiusLg),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.95),
                    scheme.tertiary.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              height: 1.2,
                            ),
                          ),
                          if (vendorVersion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              vendorVersion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                dateAndSizeLine,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.92,
                                  ),
                                  letterSpacing: 0.15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (recent)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: scheme.tertiary.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              'Recently installed',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: scheme.tertiary,
                              ),
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                          size: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
