import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/ws_models.dart';
import '../services/alert_notification_service.dart';
import 'watchlist_bloc.dart';

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
  AlertsBloc({required WatchlistBloc watchlistBloc})
      : _watchlistBloc = watchlistBloc,
        super(const AlertsState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final WatchlistBloc _watchlistBloc;

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type'] != 'alert') return;
    final raw = m['data'];
    if (raw is! Map) return;
    final a = Alert.fromJson(Map<String, dynamic>.from(raw));
    emit(state.copyWith(items: [a, ...state.items].take(500).toList()));
    final watchLower = _watchlistBloc.state.entries
        .map((e) => e.name.toLowerCase())
        .toSet();
    unawaited(
        AlertNotificationService.maybeShowForAlert(a, watchlistExecutableNamesLower: watchLower));
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
