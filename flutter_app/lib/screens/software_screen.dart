import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/software_bloc.dart';
import '../widgets/em_brand_app_bar.dart';

class SoftwareScreen extends StatefulWidget {
  const SoftwareScreen({super.key});

  @override
  State<SoftwareScreen> createState() => _SoftwareScreenState();
}

class _SoftwareScreenState extends State<SoftwareScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SoftwareBloc>().request();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search name or vendor',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: BlocBuilder<SoftwareBloc, SoftwareState>(
              builder: (context, state) {
                if (state.loading && state.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final q = _search.text.trim().toLowerCase();
                final list = state.items.where((s) {
                  if (q.isEmpty) return true;
                  return s.name.toLowerCase().contains(q) || s.vendor.toLowerCase().contains(q);
                }).toList();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return Material(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(4),
                      child: ListTile(
                        title: Text(s.name),
                        subtitle: Text('${s.vendor} · ${s.version} · ${s.installDate}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
