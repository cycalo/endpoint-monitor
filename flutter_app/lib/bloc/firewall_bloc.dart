import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class FirewallBlockEntry extends Equatable {
  const FirewallBlockEntry({
    required this.blockKind,
    this.ip,
    required this.direction,
    required this.createdAt,
    this.sourceProcessName,
    this.remotePort,
    this.expiresAt,
    this.processName,
    this.executablePath,
  });

  /// `ip`, `port`, or `process` (matches service snapshot).
  final String blockKind;
  final String? ip;
  final String direction;
  final DateTime createdAt;
  final String? sourceProcessName;
  final int? remotePort;
  final DateTime? expiresAt;
  final String? processName;
  final String? executablePath;

  @override
  List<Object?> get props => [
        blockKind,
        ip,
        direction,
        createdAt,
        sourceProcessName,
        remotePort,
        expiresAt,
        processName,
        executablePath,
      ];
}

class FirewallState extends Equatable {
  const FirewallState({
    this.isolated = false,
    this.blocks = const [],
    this.snapshotLoading = false,
    this.waitingFirstSnapshot = true,
    this.pullRefreshing = false,
    this.errorMessage,
    this.snackbarMessage,
  });

  final bool isolated;
  final List<FirewallBlockEntry> blocks;
  final bool snapshotLoading;
  final bool waitingFirstSnapshot;
  final bool pullRefreshing;
  final String? errorMessage;
  final String? snackbarMessage;

  List<FirewallBlockEntry> get ipAndPortBlocks => blocks
      .where((e) => e.blockKind == 'ip' || e.blockKind == 'port')
      .toList();

  List<FirewallBlockEntry> get processBlocks =>
      blocks.where((e) => e.blockKind == 'process').toList();

  FirewallState copyWith({
    bool? isolated,
    List<FirewallBlockEntry>? blocks,
    bool? snapshotLoading,
    bool? waitingFirstSnapshot,
    bool? pullRefreshing,
    String? errorMessage,
    bool clearError = false,
    String? snackbarMessage,
    bool clearSnackbar = false,
  }) {
    return FirewallState(
      isolated: isolated ?? this.isolated,
      blocks: blocks ?? this.blocks,
      snapshotLoading: snapshotLoading ?? this.snapshotLoading,
      waitingFirstSnapshot: waitingFirstSnapshot ?? this.waitingFirstSnapshot,
      pullRefreshing: pullRefreshing ?? this.pullRefreshing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      snackbarMessage:
          clearSnackbar ? null : snackbarMessage ?? this.snackbarMessage,
    );
  }

  @override
  List<Object?> get props => [
        isolated,
        blocks,
        snapshotLoading,
        waitingFirstSnapshot,
        pullRefreshing,
        errorMessage,
        snackbarMessage,
      ];
}

class FirewallBloc extends Cubit<FirewallState> {
  FirewallBloc() : super(const FirewallState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  Timer? _snapshotTimeout;
  bool _pendingIsolate = false;
  bool _pendingUnisolate = false;
  String? _pendingUnblockIp;
  String? _pendingManualBlockIp;
  int? _pendingQuickPort;
  String? _pendingProcessBlockName;
  String? _pendingUnblockProcessName;
  String? _pendingUnblockProcessDir;

  static int? _parsePort(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);

    final type = m['type'] as String?;
    if (type == 'firewall') {
      final raw = m['data'];
      if (raw is Map) {
        _applySnapshot(Map<String, dynamic>.from(raw));
      }
      return;
    }

    if (type == 'command_result') {
      _handleCommandResult(m);
    }
  }

  void _applySnapshot(Map<String, dynamic> data) {
    _snapshotTimeout?.cancel();
    final isolated = data['isolated'] as bool? ?? false;
    final rawBlocks = data['blocks'];
    final list = <FirewallBlockEntry>[];
    if (rawBlocks is List) {
      for (final e in rawBlocks) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        final ipVal = row['ip'] as String?;
        var kind = (row['blockKind'] as String? ?? '').toLowerCase();
        if (kind.isEmpty) {
          final s = ipVal ?? '';
          kind = s.startsWith('port:') ? 'port' : 'ip';
        }
        final dir = (row['direction'] as String? ?? 'outbound').toLowerCase();
        final created =
            DateTime.tryParse(row['createdAt'] as String? ?? '')?.toUtc() ??
                DateTime.now().toUtc();
        final srcRaw = row['sourceProcessName'];
        final String? src = srcRaw is String ? srcRaw : null;
        final trimmed = src?.trim();
        final exp = DateTime.tryParse(row['expiresAt'] as String? ?? '')
            ?.toUtc();
        final procName = row['processName'] as String?;
        final exePath = row['executablePath'] as String?;
        list.add(FirewallBlockEntry(
          blockKind: kind,
          ip: ipVal,
          direction: dir,
          createdAt: created,
          sourceProcessName:
              trimmed != null && trimmed.isNotEmpty ? trimmed : null,
          remotePort: _parsePort(row['remotePort']),
          expiresAt: exp,
          processName: procName?.trim().isNotEmpty == true ? procName : null,
          executablePath:
              exePath?.trim().isNotEmpty == true ? exePath : null,
        ));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(
      isolated: isolated,
      blocks: list,
      snapshotLoading: false,
      pullRefreshing: false,
      waitingFirstSnapshot: false,
      clearError: true,
    ));
  }

  void _handleCommandResult(Map<String, dynamic> m) {
    final cmd = m['command'] as String?;
    final ok = m['success'] == true;
    final msg = m['message']?.toString() ?? 'Unknown error';

    if (cmd == 'isolate_machine' && _pendingIsolate) {
      _pendingIsolate = false;
      if (!ok) emit(state.copyWith(snackbarMessage: 'Isolation failed: $msg'));
      return;
    }
    if (cmd == 'unisolate_machine' && _pendingUnisolate) {
      _pendingUnisolate = false;
      if (!ok) {
        emit(state.copyWith(snackbarMessage: 'Failed to unisolate: $msg'));
      }
      return;
    }
    if (cmd == 'unblock_ip' && _pendingUnblockIp != null) {
      _pendingUnblockIp = null;
      if (ok) {
        emit(state.copyWith(snackbarMessage: 'Removed block'));
      } else {
        emit(state.copyWith(snackbarMessage: 'Unblock failed: $msg'));
      }
      return;
    }
    if (cmd == 'unblock_process' &&
        _pendingUnblockProcessName != null &&
        _pendingUnblockProcessDir != null) {
      _pendingUnblockProcessName = null;
      _pendingUnblockProcessDir = null;
      if (ok) {
        emit(state.copyWith(snackbarMessage: 'Process rule removed'));
      } else {
        emit(state.copyWith(snackbarMessage: 'Unblock failed: $msg'));
      }
      return;
    }
    if (cmd == 'block_ip' && _pendingManualBlockIp != null) {
      final ip = _pendingManualBlockIp!;
      _pendingManualBlockIp = null;
      if (ok) {
        emit(state.copyWith(snackbarMessage: 'Block added for $ip'));
      } else {
        emit(state.copyWith(snackbarMessage: 'Block failed: $msg'));
      }
      return;
    }
    if (cmd == 'block_outbound_port' && _pendingQuickPort != null) {
      final p = _pendingQuickPort!;
      _pendingQuickPort = null;
      if (ok) {
        emit(state.copyWith(snackbarMessage: 'Outbound port $p blocked'));
      } else {
        emit(state.copyWith(snackbarMessage: 'Port block failed: $msg'));
      }
      return;
    }
    if (cmd == 'block_process' && _pendingProcessBlockName != null) {
      final n = _pendingProcessBlockName!;
      _pendingProcessBlockName = null;
      if (ok) {
        emit(state.copyWith(snackbarMessage: 'Blocked $n'));
      } else {
        emit(state.copyWith(snackbarMessage: 'Process block failed: $msg'));
      }
    }
  }

  void clearFeedback() {
    emit(state.copyWith(clearSnackbar: true));
  }

  void refresh({bool isPull = false}) {
    emit(state.copyWith(
      snapshotLoading: true,
      pullRefreshing: isPull,
      clearError: true,
    ));
    _startSnapshotTimeout();
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'type': 'get_firewall_snapshot'}),
    );
  }

  void _startSnapshotTimeout() {
    _snapshotTimeout?.cancel();
    _snapshotTimeout = Timer(const Duration(seconds: 15), () {
      if (isClosed || !state.snapshotLoading) return;
      emit(state.copyWith(
        snapshotLoading: false,
        pullRefreshing: false,
        waitingFirstSnapshot: false,
        errorMessage:
            'Could not load firewall data from the service. Check the connection and try again.',
      ));
    });
  }

  void sendCommand(Map<String, dynamic> cmd) {
    FlutterForegroundTask.sendDataToTask(jsonEncode(cmd));
  }

  static Map<String, dynamic> _withExpiryHours(
    Map<String, dynamic> cmd,
    int? expiresInHours,
  ) {
    if (expiresInHours != null && expiresInHours > 0) {
      cmd['expiresInHours'] = expiresInHours;
    }
    return cmd;
  }

  void requestIsolate() {
    _pendingIsolate = true;
    sendCommand({'type': 'isolate_machine'});
  }

  void requestUnisolate() {
    _pendingUnisolate = true;
    sendCommand({'type': 'unisolate_machine'});
  }

  /// [ip] is the service primary key: IPv4/IPv6 or `port:N` for outbound port rules.
  void requestUnblockIpOrPortKey(String ip) {
    _pendingUnblockIp = ip;
    sendCommand({'type': 'unblock_ip', 'ip': ip});
  }

  void requestUnblockProcess(String name, String direction) {
    _pendingUnblockProcessName = name;
    _pendingUnblockProcessDir = direction;
    sendCommand({
      'type': 'unblock_process',
      'name': name,
      'direction': direction,
    });
  }

  void requestUnblockEntry(FirewallBlockEntry e) {
    if (e.blockKind == 'process') {
      final n = e.processName;
      if (n == null || n.isEmpty) return;
      requestUnblockProcess(n, e.direction);
    } else {
      final key = e.ip;
      if (key == null || key.isEmpty) return;
      requestUnblockIpOrPortKey(key);
    }
  }

  void requestManualBlock(
    String ip,
    String direction, {
    int? remotePort,
    int? expiresInHours,
  }) {
    final trimmed = ip.trim();
    _pendingManualBlockIp = trimmed;
    final cmd = _withExpiryHours({
      'type': 'block_ip',
      'ip': trimmed,
      'direction': direction,
    }, expiresInHours);
    if (remotePort != null && remotePort >= 1 && remotePort <= 65535) {
      cmd['port'] = remotePort;
    }
    sendCommand(cmd);
  }

  void requestBlockOutboundPort(int port, {int? expiresInHours}) {
    _pendingQuickPort = port;
    sendCommand(_withExpiryHours({
      'type': 'block_outbound_port',
      'port': port,
    }, expiresInHours));
  }

  void requestBlockProcess(
    String name, {
    required String direction,
    int? expiresInHours,
  }) {
    _pendingProcessBlockName = name.trim();
    sendCommand(_withExpiryHours({
      'type': 'block_process',
      'name': name.trim(),
      'direction': direction,
    }, expiresInHours));
  }

  @override
  Future<void> close() {
    _snapshotTimeout?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
