import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';
import '../utils/em_snapshot_cache.dart';

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
    this.vtByPid = const {},
    this.vtLoadingPid,
    this.fromCache = false,
  });

  final List<ProcessInfo> items;
  final bool loading;
  final bool fromCache;

  /// PIDs we have suspended from this app session (WMI does not report suspension).
  final Set<int> suspendedPids;

  /// Recently killed processes (same PID as at kill time). Dropped if that PID appears
  /// again on the host (new process) or after [ProcessBloc._ghostTtl].
  final List<KilledProcessGhost> killedGhosts;

  /// Latest VirusTotal `check_reputation` payload per PID (service-side hash cache).
  final Map<int, Map<String, dynamic>> vtByPid;
  final int? vtLoadingPid;

  ProcessState copyWith({
    List<ProcessInfo>? items,
    bool? loading,
    Set<int>? suspendedPids,
    List<KilledProcessGhost>? killedGhosts,
    Map<int, Map<String, dynamic>>? vtByPid,
    int? vtLoadingPid,
    bool clearVtLoadingPid = false,
    bool? fromCache,
  }) =>
      ProcessState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        suspendedPids: suspendedPids ?? this.suspendedPids,
        killedGhosts: killedGhosts ?? this.killedGhosts,
        vtByPid: vtByPid ?? this.vtByPid,
        vtLoadingPid:
            clearVtLoadingPid ? null : (vtLoadingPid ?? this.vtLoadingPid),
        fromCache: fromCache ?? this.fromCache,
      );

  @override
  List<Object?> get props => [
        items,
        loading,
        fromCache,
        _sorted(suspendedPids),
        _ghostKey(killedGhosts),
        _vtKey(vtByPid),
        vtLoadingPid,
      ];

  static String _vtKey(Map<int, Map<String, dynamic>> m) {
    final keys = m.keys.toList()..sort();
    return keys.map((k) => '$k:${m[k]!.toString()}').join('|');
  }

  static List<int> _sorted(Set<int> s) => List<int>.from(s)..sort();

  static List<Object?> _ghostKey(List<KilledProcessGhost> g) =>
      g.map((e) => '${e.pid}:${e.killedAt.millisecondsSinceEpoch}').toList()..sort();
}

class ProcessBloc extends Cubit<ProcessState> {
  ProcessBloc() : super(const ProcessState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cached = await EmSnapshotCache.loadProcesses();
    if (cached.isNotEmpty && !isClosed) {
      emit(state.copyWith(items: cached, loading: false, fromCache: true));
    }
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
      if (cmd == 'check_reputation') {
        final pending = state.vtLoadingPid;
        final data = m['data'];
        final nextVt = Map<int, Map<String, dynamic>>.from(state.vtByPid);
        if (pending != null && data is Map) {
          nextVt[pending] = Map<String, dynamic>.from(data);
        }
        emit(state.copyWith(
          vtByPid: nextVt,
          clearVtLoadingPid: true,
        ));
        return;
      }
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
    EmSnapshotCache.saveProcessesRaw(raw);
    final list = raw.map((e) => ProcessInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final alive = list.map((e) => e.pid).toSet();
    final prunedSuspended = state.suspendedPids.where(alive.contains).toSet();
    final prunedGhosts = _pruneGhosts(state.killedGhosts, alive);
    emit(state.copyWith(
      items: list,
      loading: false,
      fromCache: false,
      suspendedPids: prunedSuspended,
      killedGhosts: prunedGhosts,
    ));
  }

  /// Nudge the agent for fresh data (next broadcast + system info ping).
  void requestRefresh() {
    if (state.items.isEmpty) {
      emit(state.copyWith(loading: true));
    }
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'get_system_info'}));
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

  void requestVirusTotalCheck(int pid) {
    emit(state.copyWith(vtLoadingPid: pid));
    sendCommand({'type': 'check_reputation', 'pid': pid});
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
