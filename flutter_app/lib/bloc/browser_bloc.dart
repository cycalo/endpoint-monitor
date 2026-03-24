import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';

class BrowserState extends Equatable {
  const BrowserState({this.items = const [], this.loading = false});

  final List<BrowserHistoryEntry> items;
  final bool loading;

  BrowserState copyWith({List<BrowserHistoryEntry>? items, bool? loading}) =>
      BrowserState(items: items ?? this.items, loading: loading ?? this.loading);

  @override
  List<Object?> get props => [items, loading];
}

class BrowserBloc extends Cubit<BrowserState> {
  BrowserBloc() : super(const BrowserState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void request(String browser) {
    emit(state.copyWith(loading: true));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'get_browser_history', 'browser': browser}));
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'browser_history') return;
    final raw = m['data'];
    if (raw is! List) return;
    final list = raw.map((e) => BrowserHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    emit(state.copyWith(items: list, loading: false));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
