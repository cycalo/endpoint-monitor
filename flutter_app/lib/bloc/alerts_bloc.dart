import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';
import '../services/alert_notification_service.dart';

class AlertsState extends Equatable {
  const AlertsState({this.items = const [], this.acked = const {}});

  final List<Alert> items;
  final Set<String> acked;

  AlertsState copyWith({List<Alert>? items, Set<String>? acked}) =>
      AlertsState(items: items ?? this.items, acked: acked ?? this.acked);

  @override
  List<Object?> get props => [items, acked];
}

class AlertsBloc extends Cubit<AlertsState> {
  AlertsBloc() : super(const AlertsState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'alert') return;
    final raw = m['data'];
    if (raw is! Map) return;
    final a = Alert.fromJson(Map<String, dynamic>.from(raw));
    emit(state.copyWith(items: [a, ...state.items].take(500).toList()));
    unawaited(AlertNotificationService.maybeShowForAlert(a));
  }

  void acknowledge(String id) {
    emit(state.copyWith(acked: {...state.acked, id}));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'ack_alert', 'id': id}));
  }

  void clearAcknowledged() {
    emit(AlertsState(items: state.items, acked: const {}));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
