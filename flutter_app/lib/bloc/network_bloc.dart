import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';
import '../utils/em_snapshot_cache.dart';

class NetworkState extends Equatable {
  const NetworkState({
    this.items = const [],
    this.loading = true,
    this.fromCache = false,
  });

  final List<NetworkConnection> items;
  final bool loading;
  final bool fromCache;

  NetworkState copyWith({
    List<NetworkConnection>? items,
    bool? loading,
    bool? fromCache,
  }) =>
      NetworkState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        fromCache: fromCache ?? this.fromCache,
      );

  @override
  List<Object?> get props => [items, loading, fromCache];
}

class NetworkBloc extends Cubit<NetworkState> {
  NetworkBloc() : super(const NetworkState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cached = await EmSnapshotCache.loadNetwork();
    if (cached.isNotEmpty && !isClosed) {
      emit(state.copyWith(items: cached, loading: false, fromCache: true));
    }
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'network') return;
    final raw = m['data'];
    if (raw is! List) return;
    EmSnapshotCache.saveNetworkRaw(raw);
    final list = raw
        .map((e) =>
            NetworkConnection.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    emit(state.copyWith(items: list, loading: false, fromCache: false));
  }

  void sendCommand(Map<String, dynamic> cmd) {
    FlutterForegroundTask.sendDataToTask(jsonEncode(cmd));
  }

  void requestRefresh() {
    if (state.items.isEmpty) {
      emit(state.copyWith(loading: true));
    }
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'get_system_info'}));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
