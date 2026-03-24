import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/browser_bloc.dart';
import '../widgets/em_brand_app_bar.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: scheme.primary,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.outlineVariant,
          onTap: (i) {
            final b = switch (i) {
              0 => 'all',
              1 => 'chrome',
              2 => 'edge',
              _ => 'firefox',
            };
            context.read<BrowserBloc>().request(b);
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Chrome'),
            Tab(text: 'Edge'),
            Tab(text: 'Firefox'),
          ],
        ),
      ),
      body: BlocBuilder<BrowserBloc, BrowserState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              final b = switch (_tabs.index) {
                0 => 'all',
                1 => 'chrome',
                2 => 'edge',
                _ => 'firefox',
              };
              context.read<BrowserBloc>().request(b);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final e = state.items[i];
                return Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                  child: ListTile(
                    title: Text(e.title.isEmpty ? e.url : e.title),
                    subtitle: Text('${e.browser} · ${e.visitTime}'),
                    onTap: () {},
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {},
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
