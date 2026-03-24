import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';

class SystemInfoState extends Equatable {
  const SystemInfoState({this.info});

  final SystemInfo? info;

  SystemInfoState copyWith({SystemInfo? info}) => SystemInfoState(info: info ?? this.info);

  @override
  List<Object?> get props => [info];
}

class SystemInfoBloc extends Cubit<SystemInfoState> {
  SystemInfoBloc() : super(const SystemInfoState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'system_info') return;
    final raw = m['data'];
    if (raw is! Map) return;
    emit(state.copyWith(info: SystemInfo.fromJson(Map<String, dynamic>.from(raw))));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
