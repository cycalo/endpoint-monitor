import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class WatchlistEntry extends Equatable {
  const WatchlistEntry({required this.name, this.addedAt});

  final String name;
  final DateTime? addedAt;

  @override
  List<Object?> get props => [name, addedAt];
}

class WatchlistState extends Equatable {
  const WatchlistState({
    this.entries = const [],
    this.lastSeenByName = const {},
    this.lastSeenLoadingNames = const {},
    this.serverListLoading = false,
    this.addError,
  });

  final List<WatchlistEntry> entries;
  final Map<String, DateTime?> lastSeenByName;
  final Set<String> lastSeenLoadingNames;
  final bool serverListLoading;
  final String? addError;

  WatchlistState copyWith({
    List<WatchlistEntry>? entries,
    Map<String, DateTime?>? lastSeenByName,
    Set<String>? lastSeenLoadingNames,
    bool? serverListLoading,
    String? addError,
    bool clearAddError = false,
  }) =>
      WatchlistState(
        entries: entries ?? this.entries,
        lastSeenByName: lastSeenByName ?? this.lastSeenByName,
        lastSeenLoadingNames: lastSeenLoadingNames ?? this.lastSeenLoadingNames,
        serverListLoading: serverListLoading ?? this.serverListLoading,
        addError: clearAddError ? null : addError ?? this.addError,
      );

  @override
  List<Object?> get props =>
      [entries, lastSeenByName, lastSeenLoadingNames, serverListLoading, addError];
}

class WatchlistBloc extends Cubit<WatchlistState> {
  WatchlistBloc() : super(const WatchlistState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final List<String> _lastSeenQueue = [];

  static final _exeLike = RegExp(r'\.(exe|com|bat|cmd|msi)$', caseSensitive: false);

  void refreshFromServer() {
    emit(state.copyWith(serverListLoading: true));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'get_flagged_processes'}));
  }

  void addName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      emit(state.copyWith(addError: 'Enter a process name'));
      return;
    }
    final normalized = name.toLowerCase().endsWith('.exe') ||
            name.toLowerCase().endsWith('.com') ||
            name.toLowerCase().endsWith('.bat') ||
            name.toLowerCase().endsWith('.cmd') ||
            name.toLowerCase().endsWith('.msi')
        ? name
        : '$name.exe';
    if (!_exeLike.hasMatch(normalized)) {
      emit(state.copyWith(addError: 'Use an executable name (e.g. notepad.exe)'));
      return;
    }
    if (state.entries.any((e) => e.name.toLowerCase() == normalized.toLowerCase())) {
      emit(state.copyWith(addError: 'Already on watchlist'));
      return;
    }
    emit(state.copyWith(clearAddError: true));
    final now = DateTime.now().toUtc();
    final next = [
      ...state.entries,
      WatchlistEntry(name: normalized, addedAt: now),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    emit(state.copyWith(
      entries: next,
      lastSeenByName: {...state.lastSeenByName, normalized: null},
    ));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'flag_process', 'name': normalized}));
    _enqueueLastSeenFetch(normalized);
  }

  void remove(String name) {
    emit(state.copyWith(
      entries: state.entries.where((e) => e.name != name).toList(),
      lastSeenByName: Map.from(state.lastSeenByName)..remove(name),
    ));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'unflag_process', 'name': name}));
  }

  void clearAddError() => emit(state.copyWith(clearAddError: true));

  void _enqueueLastSeenFetch(String name) {
    if (!_lastSeenQueue.contains(name)) {
      _lastSeenQueue.add(name);
    }
    _pumpLastSeenQueue();
  }

  void _pumpLastSeenQueue() {
    if (_lastSeenQueue.isEmpty) {
      emit(state.copyWith(lastSeenLoadingNames: const {}));
      return;
    }
    final name = _lastSeenQueue.first;
    emit(state.copyWith(
      lastSeenLoadingNames: {...state.lastSeenLoadingNames, name},
    ));
    FlutterForegroundTask.sendDataToTask(jsonEncode({
      'type': 'get_recent_events',
      'limit': 120,
      'processFilter': name,
      'typeFilter': 'ProcessCreate',
    }));
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    final type = m['type'] as String?;

    if (type == 'flagged_processes') {
      final raw = m['data'];
      final list = <WatchlistEntry>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final row = Map<String, dynamic>.from(e);
          final n = row['name'] as String? ?? '';
          if (n.isEmpty) continue;
          final ad = DateTime.tryParse(row['addedAt'] as String? ?? '')?.toUtc();
          list.add(WatchlistEntry(name: n, addedAt: ad));
        }
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final seenMap = Map<String, DateTime?>.from(state.lastSeenByName);
      for (final e in list) {
        seenMap.putIfAbsent(e.name, () => null);
      }
      emit(state.copyWith(
        entries: list,
        lastSeenByName: seenMap,
        serverListLoading: false,
      ));
      _lastSeenQueue.clear();
      _lastSeenQueue.addAll(list.map((e) => e.name));
      _pumpLastSeenQueue();
      return;
    }

    if (type == 'command_result') {
      final cmd = m['command'] as String?;
      final ok = m['success'] == true;
      if (cmd == 'get_recent_events' && _lastSeenQueue.isNotEmpty) {
        final name = _lastSeenQueue.removeAt(0);
        DateTime? latest;
        if (ok) {
          final raw = m['data'];
          if (raw is List) {
            final want = name.toLowerCase();
            for (final e in raw) {
              if (e is! Map) continue;
              final row = Map<String, dynamic>.from(e);
              if ((row['type'] as String? ?? '') != 'ProcessCreate') continue;
              final pn = (row['processName'] as String? ?? '').toLowerCase();
              if (pn != want && !pn.endsWith('\\$want') && !pn.endsWith('/$want')) {
                continue;
              }
              final ts = DateTime.tryParse(row['timestamp'] as String? ?? '')?.toUtc();
              if (ts != null && (latest == null || ts.isAfter(latest))) {
                latest = ts;
              }
            }
          }
        }
        final nextSeen = Map<String, DateTime?>.from(state.lastSeenByName);
        nextSeen[name] = latest;
        final loading = Set<String>.from(state.lastSeenLoadingNames)..remove(name);
        emit(state.copyWith(lastSeenByName: nextSeen, lastSeenLoadingNames: loading));
        _pumpLastSeenQueue();
      }
      return;
    }
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
