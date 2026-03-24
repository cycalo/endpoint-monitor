import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';

class NetworkState extends Equatable {
  const NetworkState({this.items = const [], this.loading = true});

  final List<NetworkConnection> items;
  final bool loading;

  NetworkState copyWith({List<NetworkConnection>? items, bool? loading}) =>
      NetworkState(items: items ?? this.items, loading: loading ?? this.loading);

  @override
  List<Object?> get props => [items, loading];
}

class NetworkBloc extends Cubit<NetworkState> {
  NetworkBloc() : super(const NetworkState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'network') return;
    final raw = m['data'];
    if (raw is! List) return;
    final list = raw.map((e) => NetworkConnection.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    emit(state.copyWith(items: list, loading: false));
  }

  void sendCommand(Map<String, dynamic> cmd) {
    FlutterForegroundTask.sendDataToTask(jsonEncode(cmd));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
