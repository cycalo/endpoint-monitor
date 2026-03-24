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
    if (m['type'] != 'sysmon_event') return;
    final raw = m['data'];
    if (raw is! Map) return;
    final ev = SysmonEvent.fromJson(Map<String, dynamic>.from(raw));
    emit(state.copyWith(items: [ev, ...state.items].take(2000).toList()));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
