import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/ws_models.dart';

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
  AlertsBloc(this._notifications) : super(const AlertsState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final FlutterLocalNotificationsPlugin _notifications;

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'alert') return;
    final raw = m['data'];
    if (raw is! Map) return;
    final a = Alert.fromJson(Map<String, dynamic>.from(raw));
    emit(state.copyWith(items: [a, ...state.items].take(500).toList()));
    if (a.severity == 'high') {
      unawaited(_showNotification(a));
    }
  }

  Future<void> _showNotification(Alert a) async {
    const android = AndroidNotificationDetails(
      'em_alerts',
      'Endpoint alerts',
      channelDescription: 'High severity endpoint alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(
      a.id.hashCode,
      'Endpoint alert',
      a.message,
      details,
    );
  }

  void acknowledge(String id) {
    emit(state.copyWith(acked: {...state.acked, id}));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'ack_alert', 'id': id}));
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
