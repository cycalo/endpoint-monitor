import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';

class EventsState extends Equatable {
  const EventsState({this.items = const []});

  final List<SysmonEvent> items;

  EventsState copyWith({List<SysmonEvent>? items}) => EventsState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
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
        m['command']?.toString() == 'get_recent_events' &&
        m['success'] == true) {
      final raw = m['data'];
      if (raw is! List) return;
      final list = raw
          .map((e) => SysmonEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      emit(state.copyWith(items: list));
    }
  }

  void loadRecent({int limit = 500}) {
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'get_recent_events', 'limit': limit}));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
