import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ControlsFeedback extends Equatable {
  const ControlsFeedback({required this.success, required this.message});

  final bool success;
  final String message;

  @override
  List<Object?> get props => [success, message];
}

class ControlsState extends Equatable {
  const ControlsState({
    this.pending = const {},
    this.feedback,
  });

  final Set<String> pending;
  final ControlsFeedback? feedback;

  ControlsState copyWith({
    Set<String>? pending,
    ControlsFeedback? feedback,
    bool clearFeedback = false,
  }) =>
      ControlsState(
        pending: pending ?? this.pending,
        feedback: clearFeedback ? null : (feedback ?? this.feedback),
      );

  @override
  List<Object?> get props => [pending, feedback];
}

/// Remote system control commands (Windows service).
class ControlsBloc extends Cubit<ControlsState> {
  ControlsBloc() : super(const ControlsState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  static const _commands = {
    'lock_screen',
    'logoff_user',
    'restart_machine',
    'shutdown_machine',
    'sleep_machine',
    'cancel_shutdown',
    'turn_off_display',
  };

  void clearFeedback() => emit(state.copyWith(clearFeedback: true));

  void send(Map<String, dynamic> cmd) {
    final t = cmd['type']?.toString();
    if (t == null || !_commands.contains(t)) return;
    emit(state.copyWith(
      pending: {...state.pending, t},
      clearFeedback: true,
    ));
    FlutterForegroundTask.sendDataToTask(jsonEncode(cmd));
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type']?.toString() != 'command_result') return;
    final cmd = m['command']?.toString();
    if (cmd == null || !_commands.contains(cmd)) return;
    final ok = m['success'] == true;
    final msg = m['message']?.toString() ?? '';
    final next = Set<String>.from(state.pending)..remove(cmd);
    emit(state.copyWith(
      pending: next,
      feedback: ControlsFeedback(success: ok, message: msg.isNotEmpty ? msg : (ok ? 'OK' : 'Failed')),
    ));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
