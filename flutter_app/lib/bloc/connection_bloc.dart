import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../task/task_entry.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class EmConnectionState extends Equatable {
  const EmConnectionState({
    required this.status,
    this.message,
    this.host,
    this.connectedAt,
    this.lastTestPingMs,
    this.lastTestPingError,
  });

  final ConnectionStatus status;
  final String? message;
  final String? host;

  /// When the foreground task reported `connected` (WebSocket open).
  final DateTime? connectedAt;

  /// Result of last Settings "Test connection" latency probe.
  final int? lastTestPingMs;
  final String? lastTestPingError;

  EmConnectionState copyWith({
    ConnectionStatus? status,
    String? message,
    String? host,
    DateTime? connectedAt,
    bool clearConnectedAt = false,
    int? lastTestPingMs,
    String? lastTestPingError,
    bool clearPingTest = false,
  }) =>
      EmConnectionState(
        status: status ?? this.status,
        message: message ?? this.message,
        host: host ?? this.host,
        connectedAt: clearConnectedAt ? null : connectedAt ?? this.connectedAt,
        lastTestPingMs: clearPingTest ? null : lastTestPingMs ?? this.lastTestPingMs,
        lastTestPingError: clearPingTest ? null : lastTestPingError ?? this.lastTestPingError,
      );

  bool get isConnected => status == ConnectionStatus.connected;

  @override
  List<Object?> get props =>
      [status, message, host, connectedAt, lastTestPingMs, lastTestPingError];
}

abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();
  @override
  List<Object?> get props => [];
}

class ConnectionStarted extends ConnectionEvent {
  const ConnectionStarted();
}

class ConnectionConnectRequested extends ConnectionEvent {
  const ConnectionConnectRequested({required this.host, required this.token});

  final String host;
  final String token;

  @override
  List<Object?> get props => [host, token];
}

class ConnectionDisconnectRequested extends ConnectionEvent {
  const ConnectionDisconnectRequested();
}

class ConnectionPingMeasureRequested extends ConnectionEvent {
  const ConnectionPingMeasureRequested();
}

class ConnectionTaskMessage extends ConnectionEvent {
  const ConnectionTaskMessage(this.raw);

  final Map<String, dynamic> raw;

  @override
  List<Object?> get props => [raw];
}

class ConnectionBloc extends Bloc<ConnectionEvent, EmConnectionState> {
  ConnectionBloc(this._storage) : super(const EmConnectionState(status: ConnectionStatus.disconnected)) {
    on<ConnectionStarted>(_onStarted);
    on<ConnectionConnectRequested>(_onConnect);
    on<ConnectionDisconnectRequested>(_onDisconnect);
    on<ConnectionPingMeasureRequested>(_onPingMeasure);
    on<ConnectionTaskMessage>(_onTaskMessage);
    FlutterForegroundTask.addTaskDataCallback(_taskCallback);
  }

  final FlutterSecureStorage _storage;
  static const _hostKey = 'em_host';
  static const _tokenKey = 'em_token';

  void _taskCallback(Object data) {
    if (data is Map) {
      add(ConnectionTaskMessage(Map<String, dynamic>.from(data)));
    }
  }

  Future<void> _onStarted(ConnectionStarted event, Emitter<EmConnectionState> emit) async {
    final host = await _storage.read(key: _hostKey);
    final token = await _storage.read(key: _tokenKey);
    if (host != null && token != null) {
      add(ConnectionConnectRequested(host: host, token: token));
    }
  }

  Future<void> _onConnect(ConnectionConnectRequested event, Emitter<EmConnectionState> emit) async {
    emit(state.copyWith(status: ConnectionStatus.connecting, message: null, host: event.host));
    final wsUrl = _normalizeWsUrl(event.host);
    await _storage.write(key: _hostKey, value: event.host.trim());
    await _storage.write(key: _tokenKey, value: event.token);
    await FlutterForegroundTask.saveData(key: 'ws_host', value: wsUrl);
    await FlutterForegroundTask.saveData(key: 'ws_token', value: event.token);

    final running = await FlutterForegroundTask.isRunningService;
    if (running) {
      FlutterForegroundTask.sendDataToTask(<String, Object?>{
        'action': 'em_connect',
        'host': wsUrl,
        'token': event.token,
      });
    } else {
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: 1000,
        notificationTitle: 'Endpoint Monitor',
        notificationText: 'Monitoring active',
        callback: endpointMonitorStartCallback,
      );
      switch (result) {
        case ServiceRequestFailure(:final error):
          emit(state.copyWith(status: ConnectionStatus.error, message: error.toString()));
        case ServiceRequestSuccess():
          break;
      }
    }
  }

  Future<void> _onDisconnect(ConnectionDisconnectRequested event, Emitter<EmConnectionState> emit) async {
    FlutterForegroundTask.sendDataToTask(<String, Object?>{'action': 'em_disconnect'});
    await FlutterForegroundTask.stopService();
    await _storage.delete(key: _hostKey);
    await _storage.delete(key: _tokenKey);
    emit(const EmConnectionState(status: ConnectionStatus.disconnected));
  }

  void _onPingMeasure(ConnectionPingMeasureRequested event, Emitter<EmConnectionState> emit) {
    emit(state.copyWith(clearPingTest: true));
    FlutterForegroundTask.sendDataToTask(<String, Object?>{'action': 'em_measure_ping'});
  }

  void _onTaskMessage(ConnectionTaskMessage event, Emitter<EmConnectionState> emit) {
    final t = event.raw['type']?.toString();
    if (t == 'ping_rtt') {
      final ok = event.raw['ok'] == true;
      final ms = event.raw['ms'];
      final parsedMs = ms is int ? ms : int.tryParse(ms?.toString() ?? '');
      if (ok && parsedMs != null) {
        emit(state.copyWith(lastTestPingMs: parsedMs, lastTestPingError: null));
      } else {
        emit(state.copyWith(
          lastTestPingMs: null,
          lastTestPingError: event.raw['message']?.toString() ?? 'Ping failed',
        ));
      }
      return;
    }
    if (t == 'connection') {
      final s = event.raw['state']?.toString() ?? '';
      final msg = event.raw['message']?.toString();
      switch (s) {
        case 'connected':
          emit(state.copyWith(
            status: ConnectionStatus.connected,
            message: null,
            connectedAt: DateTime.now(),
          ));
          break;
        case 'connecting':
          emit(state.copyWith(status: ConnectionStatus.connecting));
          break;
        case 'disconnected':
        case 'error':
          emit(state.copyWith(
            status: s == 'error' ? ConnectionStatus.error : ConnectionStatus.disconnected,
            message: msg,
            clearConnectedAt: true,
          ));
          break;
        default:
          break;
      }
    }
  }

  static String _normalizeWsUrl(String host) {
    final t = host.trim();
    if (t.startsWith('ws://') || t.startsWith('wss://')) {
      return t.endsWith('/ws') ? t : (t.endsWith('/') ? '${t}ws' : '$t/ws');
    }
    return 'ws://$t/ws';
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_taskCallback);
    return super.close();
  }
}
