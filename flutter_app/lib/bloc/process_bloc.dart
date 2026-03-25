import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';

/// Snapshot shown after a successful kill until TTL / PID reuse / dismiss.
class KilledProcessGhost extends Equatable {
  const KilledProcessGhost({
    required this.pid,
    required this.snapshot,
    required this.killedAt,
  });

  final int pid;
  final ProcessInfo snapshot;
  final DateTime killedAt;

  @override
  List<Object?> get props => [pid, snapshot, killedAt];
}

class ProcessState extends Equatable {
  const ProcessState({
    this.items = const [],
    this.loading = true,
    this.suspendedPids = const {},
    this.killedGhosts = const [],
  });

  final List<ProcessInfo> items;
  final bool loading;

  /// PIDs we have suspended from this app session (WMI does not report suspension).
  final Set<int> suspendedPids;

  /// Recently killed processes (same PID as at kill time). Dropped if that PID appears
  /// again on the host (new process) or after [ProcessBloc._ghostTtl].
  final List<KilledProcessGhost> killedGhosts;

  ProcessState copyWith({
    List<ProcessInfo>? items,
    bool? loading,
    Set<int>? suspendedPids,
    List<KilledProcessGhost>? killedGhosts,
  }) =>
      ProcessState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        suspendedPids: suspendedPids ?? this.suspendedPids,
        killedGhosts: killedGhosts ?? this.killedGhosts,
      );

  @override
  List<Object?> get props => [items, loading, _sorted(suspendedPids), _ghostKey(killedGhosts)];

  static List<int> _sorted(Set<int> s) => List<int>.from(s)..sort();

  static List<Object?> _ghostKey(List<KilledProcessGhost> g) =>
      g.map((e) => '${e.pid}:${e.killedAt.millisecondsSinceEpoch}').toList()..sort();
}

class ProcessBloc extends Cubit<ProcessState> {
  ProcessBloc() : super(const ProcessState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  static const _ghostTtl = Duration(minutes: 2);
  static const _maxGhosts = 30;

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    final t = m['type']?.toString();

    if (t == 'command_result') {
      final cmd = m['command']?.toString();
      final ok = m['success'] == true;
      final pid = m['pid'];
      if (pid is int) {
        if (cmd == 'suspend_process' && !ok) {
          emit(state.copyWith(suspendedPids: {...state.suspendedPids}..remove(pid)));
        } else if (cmd == 'resume_process' && ok) {
          emit(state.copyWith(suspendedPids: {...state.suspendedPids}..remove(pid)));
        } else if (cmd == 'kill_process' && ok) {
          _onKillSucceeded(pid);
        }
      }
      return;
    }

    if (t != 'processes') return;
    final raw = m['data'];
    if (raw is! List) return;
    final list = raw.map((e) => ProcessInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final alive = list.map((e) => e.pid).toSet();
    final prunedSuspended = state.suspendedPids.where(alive.contains).toSet();
    final prunedGhosts = _pruneGhosts(state.killedGhosts, alive);
    emit(state.copyWith(items: list, loading: false, suspendedPids: prunedSuspended, killedGhosts: prunedGhosts));
  }

  void _onKillSucceeded(int pid) {
    ProcessInfo? snapshot;
    for (final p in state.items) {
      if (p.pid == pid) {
        snapshot = p;
        break;
      }
    }
    final withoutPid = state.items.where((p) => p.pid != pid).toList();
    final ghosts = List<KilledProcessGhost>.from(state.killedGhosts)..removeWhere((g) => g.pid == pid);
    if (snapshot != null) {
      ghosts.add(KilledProcessGhost(pid: pid, snapshot: snapshot, killedAt: DateTime.now()));
    }
    emit(
      state.copyWith(
        items: withoutPid,
        suspendedPids: {...state.suspendedPids}..remove(pid),
        killedGhosts: _capGhosts(_trimExpired(ghosts)),
      ),
    );
  }

  List<KilledProcessGhost> _pruneGhosts(List<KilledProcessGhost> ghosts, Set<int> alivePids) {
    final now = DateTime.now();
    return _capGhosts(
      _trimExpired(
        ghosts.where((g) {
          if (alivePids.contains(g.pid)) return false;
          return true;
        }).toList(),
        now: now,
      ),
    );
  }

  List<KilledProcessGhost> _trimExpired(List<KilledProcessGhost> ghosts, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return ghosts.where((g) => t.difference(g.killedAt) <= _ghostTtl).toList();
  }

  List<KilledProcessGhost> _capGhosts(List<KilledProcessGhost> ghosts) {
    if (ghosts.length <= _maxGhosts) return ghosts;
    final sorted = List<KilledProcessGhost>.from(ghosts)..sort((a, b) => b.killedAt.compareTo(a.killedAt));
    return sorted.take(_maxGhosts).toList();
  }

  /// Remove a killed ghost row before TTL (e.g. user dismisses).
  void dismissKilledGhost(int pid) {
    emit(
      state.copyWith(
        killedGhosts: state.killedGhosts.where((g) => g.pid != pid).toList(),
      ),
    );
  }

  void sendCommand(Map<String, dynamic> cmd) {
    final type = cmd['type']?.toString();
    final pid = cmd['pid'];
    if (type == 'suspend_process' && pid is int) {
      emit(state.copyWith(suspendedPids: {...state.suspendedPids, pid}));
    }
    FlutterForegroundTask.sendDataToTask(jsonEncode(cmd));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
