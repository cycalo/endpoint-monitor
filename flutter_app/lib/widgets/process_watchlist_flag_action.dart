import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watchlist_bloc.dart';
import '../models/ws_models.dart';

Future<void> processWatchlistFlagTap(
  BuildContext context,
  ProcessInfo p,
  bool flagged,
) async {
  final wl = context.read<WatchlistBloc>();
  final normalized = WatchlistBloc.normalizeExecutableName(p.name);
  if (normalized == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not resolve an executable name to flag'),
      ),
    );
    return;
  }
  if (!flagged) {
    wl.flagFromProcessesScreen(p.name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$normalized added to watchlist')),
    );
    return;
  }
  final stored = wl.watchlistNameForExecutable(p.name);
  if (stored == null) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Remove from watchlist?'),
      content: Text('Remove $stored from watchlist?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    wl.remove(stored);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$stored removed from watchlist')),
    );
  }
}
