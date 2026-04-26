import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';

class EventsState extends Equatable {
  const EventsState({this.items = const [], this.loading = false});

  final List<SysmonEvent> items;
  final bool loading;

  EventsState copyWith({List<SysmonEvent>? items, bool? loading}) => EventsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
      );

  @override
  List<Object?> get props => [items, loading];
}

class EventsBloc extends Cubit<EventsState> {
  EventsBloc() : super(const EventsState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    final type = m['type']?.toString() ?? '';
    if (type == 'sysmon_event') {
      final raw = m['data'];
      if (raw is! Map) return;
      final ev = SysmonEvent.fromJson(Map<String, dynamic>.from(raw));
      emit(state.copyWith(items: [ev, ...state.items].take(2000).toList()));
      return;
    }
    if (type == 'command_result' &&
        m['command']?.toString() == 'get_recent_events') {
      final ok = m['success'] == true;
      if (!ok) {
        emit(state.copyWith(loading: false));
        return;
      }
      final raw = m['data'];
      if (raw is! List) {
        emit(state.copyWith(loading: false));
        return;
      }
      final list = raw
          .map((e) => SysmonEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      emit(state.copyWith(items: list, loading: false));
    }
  }

  void loadRecent({int limit = 500, String? fromIso, String? toIso}) {
    emit(state.copyWith(loading: true));
    final payload = <String, dynamic>{'type': 'get_recent_events', 'limit': limit};
    if (fromIso != null && fromIso.isNotEmpty) payload['from'] = fromIso;
    if (toIso != null && toIso.isNotEmpty) payload['to'] = toIso;
    FlutterForegroundTask.sendDataToTask(jsonEncode(payload));
  }

  void clearAll() {
    emit(const EventsState(loading: false));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
