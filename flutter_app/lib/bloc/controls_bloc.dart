import 'dart:convert';
import 'dart:typed_data';

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
    this.screenshotPng,
  });

  final Set<String> pending;
  final ControlsFeedback? feedback;

  /// Decoded PNG from the last successful `capture_desktop_screenshot` (cleared by [clearScreenshot]).
  final Uint8List? screenshotPng;

  ControlsState copyWith({
    Set<String>? pending,
    ControlsFeedback? feedback,
    bool clearFeedback = false,
    Uint8List? screenshotPng,
    bool clearScreenshot = false,
  }) =>
      ControlsState(
        pending: pending ?? this.pending,
        feedback: clearFeedback ? null : (feedback ?? this.feedback),
        screenshotPng: clearScreenshot ? null : (screenshotPng ?? this.screenshotPng),
      );

  @override
  List<Object?> get props => [pending, feedback, screenshotPng];
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
    'set_volume',
    'toggle_mute',
    'capture_desktop_screenshot',
  };

  void clearFeedback() => emit(state.copyWith(clearFeedback: true));

  void clearScreenshot() => emit(state.copyWith(clearScreenshot: true));

  /// Sent when the user releases the volume slider (final level only).
  void setVolume(int volume) =>
      send({'type': 'set_volume', 'volume': volume.clamp(0, 100)});

  void toggleMute() => send(const {'type': 'toggle_mute'});

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

    if (cmd == 'capture_desktop_screenshot') {
      Uint8List? png;
      if (ok) {
        final raw = m['data'];
        if (raw is Map) {
          final b64 = raw['imageBase64']?.toString();
          if (b64 != null && b64.isNotEmpty) {
            try {
              png = base64Decode(b64);
            } catch (_) {
              png = null;
            }
          }
        }
      }
      emit(state.copyWith(
        pending: next,
        clearFeedback: true,
        clearScreenshot: !(ok && png != null),
        screenshotPng: (ok && png != null) ? png : null,
        feedback: ok && png != null
            ? null
            : ControlsFeedback(
                success: false,
                message: png == null && ok
                    ? 'Screenshot data missing'
                    : (msg.isNotEmpty ? msg : 'Failed'),
              ),
      ));
      return;
    }

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
