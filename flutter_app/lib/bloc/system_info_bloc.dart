import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';
import '../utils/em_snapshot_cache.dart';

class SystemInfoState extends Equatable {
  const SystemInfoState({this.info, this.fromCache = false});

  final SystemInfo? info;
  final bool fromCache;

  SystemInfoState copyWith({SystemInfo? info, bool? fromCache}) =>
      SystemInfoState(
        info: info ?? this.info,
        fromCache: fromCache ?? this.fromCache,
      );

  @override
  List<Object?> get props => [info, fromCache];
}

class SystemInfoBloc extends Cubit<SystemInfoState> {
  SystemInfoBloc() : super(const SystemInfoState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cached = await EmSnapshotCache.loadSystemInfo();
    if (cached != null && !isClosed) {
      emit(SystemInfoState(info: cached, fromCache: true));
    }
  }

  /// Ask the agent for an immediate snapshot (same message shape as periodic broadcast).
  void requestLatest() {
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'get_system_info'}));
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'system_info') return;
    final raw = m['data'];
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    EmSnapshotCache.saveSystemInfoRaw(map);
    emit(state.copyWith(
      info: SystemInfo.fromJson(map),
      fromCache: false,
    ));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
