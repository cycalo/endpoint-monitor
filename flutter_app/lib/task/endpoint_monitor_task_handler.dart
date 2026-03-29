import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_channel/io.dart';

class EndpointMonitorTaskHandler extends TaskHandler {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  bool _stopping = false;

  static const _kConnect = 'em_connect';
  static const _kDisconnect = 'em_disconnect';
  static const _kMeasurePing = 'em_measure_ping';

  Map<String, Object?> _connectionPayload(String state, {String? message}) => {
        'type': 'connection',
        'state': state,
        if (message != null) 'message': message,
      };

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _stopping = false;
    final host = await FlutterForegroundTask.getData<String>(key: 'ws_host');
    final token = await FlutterForegroundTask.getData<String>(key: 'ws_token');
    if (host == null || token == null) {
      FlutterForegroundTask.sendDataToMain(_connectionPayload('error', message: 'missing_credentials'));
      return;
    }
    unawaited(_connectLoop(host, token));
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Reserved for periodic work; ping uses its own timer.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _stopping = true;
    _pingTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final action = m['action'] as String?;
      if (action == _kDisconnect) {
        _stopping = true;
        _pingTimer?.cancel();
        unawaited(_sub?.cancel());
        unawaited(_channel?.sink.close());
        return;
      }
      if (action == _kConnect) {
        final host = m['host'] as String?;
        final token = m['token'] as String?;
        if (host != null && token != null) {
          unawaited(FlutterForegroundTask.saveData(key: 'ws_host', value: host));
          unawaited(FlutterForegroundTask.saveData(key: 'ws_token', value: token));
          _stopping = true;
          _pingTimer?.cancel();
          unawaited(_sub?.cancel());
          unawaited(_channel?.sink.close());
          _stopping = false;
          unawaited(_connectLoop(host, token));
        }
      }
      if (action == _kMeasurePing) {
        _sendLatencyPing();
      }
      return;
    }
    if (data is String) {
      try {
        _channel?.sink.add(data);
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _connectLoop(String host, String token) async {
    var delay = const Duration(seconds: 1);
    while (!_stopping) {
      try {
        FlutterForegroundTask.sendDataToMain(_connectionPayload('connecting'));
        final uri = Uri.parse(host.startsWith('ws') ? host : 'ws://$host');
        final channel = IOWebSocketChannel.connect(uri, headers: {'Authorization': 'Bearer $token'});
        _channel = channel;
        final done = Completer<void>();
        _sub = channel.stream.listen(
          (message) {
            if (message is String) {
              _forwardMessage(message);
            }
          },
          onError: (Object e) {
            FlutterForegroundTask.sendDataToMain(_connectionPayload('error', message: e.toString()));
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            FlutterForegroundTask.sendDataToMain(_connectionPayload('disconnected'));
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        _startPing();
        FlutterForegroundTask.sendDataToMain(_connectionPayload('connected'));
        delay = const Duration(seconds: 1);
        await done.future;
        _pingTimer?.cancel();
      } catch (e) {
        FlutterForegroundTask.sendDataToMain(_connectionPayload('error', message: e.toString()));
        await Future<void>.delayed(delay);
        delay = Duration(seconds: (delay.inSeconds * 2).clamp(1, 60));
      }
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        // ignore
      }
    });
  }

  void _sendLatencyPing() {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      _channel?.sink.add(jsonEncode({'type': 'ping', 'clientTs': t}));
    } catch (_) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'ping_rtt',
        'ok': false,
        'message': 'WebSocket not connected',
      });
    }
  }

  void _forwardMessage(String message) {
    try {
      final map = jsonDecode(message);
      if (map is Map<String, dynamic>) {
        if (map['type'] == 'pong' && map['clientTs'] != null) {
          final raw = map['clientTs'];
          final sent = raw is int
              ? raw
              : int.tryParse(raw.toString()) ?? 0;
          if (sent > 0) {
            final ms = DateTime.now().millisecondsSinceEpoch - sent;
            FlutterForegroundTask.sendDataToMain({
              'type': 'ping_rtt',
              'ok': true,
              'ms': ms < 0 ? 0 : ms,
            });
          }
        }
        FlutterForegroundTask.sendDataToMain(map);
      }
    } catch (_) {
      // ignore malformed
    }
  }
}
