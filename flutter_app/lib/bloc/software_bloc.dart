import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';

class SoftwareState extends Equatable {
  const SoftwareState({this.items = const [], this.loading = false});

  final List<InstalledSoftwareItem> items;
  final bool loading;

  SoftwareState copyWith({List<InstalledSoftwareItem>? items, bool? loading}) =>
      SoftwareState(items: items ?? this.items, loading: loading ?? this.loading);

  @override
  List<Object?> get props => [items, loading];
}

class SoftwareBloc extends Cubit<SoftwareState> {
  SoftwareBloc() : super(const SoftwareState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void request() {
    emit(state.copyWith(loading: true));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'get_installed_software'}));
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'installed_software') return;
    final raw = m['data'];
    if (raw is! List) return;
    final list = raw.map((e) => InstalledSoftwareItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    emit(state.copyWith(items: list, loading: false));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
