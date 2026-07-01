import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/io.dart';

import '../utils/ws_url.dart';

class EndpointMonitorTaskHandler extends TaskHandler {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  bool _stopping = false;

  static const _secureStorage = FlutterSecureStorage();
  static const _hostKey = 'em_host';
  static const _tokenKey = 'em_token';

  static const _kConnect = 'em_connect';
  static const _kDisconnect = 'em_disconnect';
  static const _kMeasurePing = 'em_measure_ping';

  Map<String, Object?> _connectionPayload(String state, {String? message}) => {
        'type': 'connection',
        'state': state,
        if (message != null) 'message': message,
      };

  Future<(String?, String?)> _loadStoredCredentials() async {
    final host = await _secureStorage.read(key: _hostKey);
    final token = await _secureStorage.read(key: _tokenKey);
    if (host == null ||
        host.trim().isEmpty ||
        token == null ||
        token.isEmpty) {
      return (null, null);
    }
    return (normalizeMonitorWsUrl(host), token);
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _stopping = false;
    final (host, token) = await _loadStoredCredentials();
    if (host == null || token == null) {
      FlutterForegroundTask.sendDataToMain(
          _connectionPayload('error', message: 'missing_credentials'));
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
    await _resetConnection();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final action = m['action'] as String?;
      if (action == _kDisconnect) {
        _stopping = true;
        unawaited(_resetConnection());
        return;
      }
      if (action == _kConnect) {
        final host = m['host'] as String?;
        final token = m['token'] as String?;
        if (host != null && token != null) {
          _stopping = true;
          unawaited(_resetConnection().then((_) {
            _stopping = false;
            return _connectLoop(host, token);
          }));
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
    try {
      FlutterForegroundTask.sendDataToMain(_connectionPayload('connecting'));
      final uri = Uri.parse(host.startsWith('ws') ? host : 'ws://$host');
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (_stopping) {
        await socket.close();
        return;
      }

      final channel = IOWebSocketChannel(socket);
      _channel = channel;
      final done = Completer<void>();
      _sub = channel.stream.listen(
        (message) {
          if (message is String) {
            _forwardMessage(message);
          }
        },
        onError: (Object e) {
          FlutterForegroundTask.sendDataToMain(
              _connectionPayload('disconnected', message: _sanitizeConnectionError(e)));
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          FlutterForegroundTask.sendDataToMain(
              _connectionPayload('disconnected'));
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );

      FlutterForegroundTask.sendDataToMain(_connectionPayload('connected'));
      _startPingTimer();
      await done.future;
    } catch (e) {
      FlutterForegroundTask.sendDataToMain(
          _connectionPayload('disconnected', message: _sanitizeConnectionError(e)));
    } finally {
      await _resetConnection();
    }
  }

  void _startPingTimer() {
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
      FlutterForegroundTask.sendDataToMain(<String, Object?>{
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
          final sent = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
          if (sent > 0) {
            final ms = DateTime.now().millisecondsSinceEpoch - sent;
            FlutterForegroundTask.sendDataToMain(<String, Object?>{
              'type': 'ping_rtt',
              'ok': true,
              'ms': ms < 0 ? 0 : ms,
            });
          }
        }
        FlutterForegroundTask.sendDataToMain(map);
      } else if (map is Map) {
        FlutterForegroundTask.sendDataToMain(Map<String, dynamic>.from(map));
      }
    } catch (_) {
      // ignore malformed payloads
    }
  }

  Future<void> _resetConnection() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // ignore
    }
    _channel = null;
  }

  static String _sanitizeConnectionError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('timed out')) {
      return 'Connection timed out.';
    }
    if (text.contains('refused')) {
      return 'Connection was refused.';
    }
    if (text.contains('network is unreachable') ||
        text.contains('no route to host') ||
        text.contains('failed host lookup')) {
      return 'Unable to reach the endpoint.';
    }
    return 'Connection lost.';
  }
}
