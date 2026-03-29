import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ThreatIntelEntry extends Equatable {
  const ThreatIntelEntry({
    required this.ip,
    required this.category,
    required this.source,
  });

  final String ip;
  final String category;
  final String source;

  @override
  List<Object?> get props => [ip, category, source];
}

class ThreatIntelState extends Equatable {
  const ThreatIntelState({
    this.entriesByIp = const {},
    this.entryCount = 0,
    this.lastRunUtc,
    this.lastError,
    this.loading = false,
  });

  final Map<String, ThreatIntelEntry> entriesByIp;
  final int entryCount;
  final String? lastRunUtc;
  final String? lastError;
  final bool loading;

  ThreatIntelEntry? lookupIp(String? remoteIp) {
    if (remoteIp == null || remoteIp.isEmpty) return null;
    return entriesByIp[remoteIp] ?? entriesByIp[_norm(remoteIp)];
  }

  static String _norm(String ip) => ip.trim();

  ThreatIntelState copyWith({
    Map<String, ThreatIntelEntry>? entriesByIp,
    int? entryCount,
    String? lastRunUtc,
    String? lastError,
    bool? loading,
  }) =>
      ThreatIntelState(
        entriesByIp: entriesByIp ?? this.entriesByIp,
        entryCount: entryCount ?? this.entryCount,
        lastRunUtc: lastRunUtc ?? this.lastRunUtc,
        lastError: lastError ?? this.lastError,
        loading: loading ?? this.loading,
      );

  @override
  List<Object?> get props =>
      [entriesByIp, entryCount, lastRunUtc, lastError, loading];
}

class ThreatIntelBloc extends Cubit<ThreatIntelState> {
  ThreatIntelBloc() : super(const ThreatIntelState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    final t = m['type']?.toString();

    if (t == 'threat_intel_entries') {
      final raw = m['data'];
      if (raw is! Map) return;
      final items = raw['items'];
      if (items is! List) return;
      final map = <String, ThreatIntelEntry>{};
      for (final e in items) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        final ip = row['ip']?.toString().trim() ?? '';
        if (ip.isEmpty) continue;
        map[ip] = ThreatIntelEntry(
          ip: ip,
          category: row['category']?.toString() ?? '',
          source: row['source']?.toString() ?? '',
        );
      }
      emit(state.copyWith(entriesByIp: map, loading: false));
      return;
    }

    if (t == 'threat_intel_status') {
      final raw = m['data'];
      if (raw is! Map) return;
      final row = Map<String, dynamic>.from(raw);
      final wasLoading = state.loading;
      emit(state.copyWith(
        entryCount: (row['entryCount'] as num?)?.toInt() ?? state.entryCount,
        lastRunUtc: row['lastRunUtc']?.toString(),
        lastError: row['lastError']?.toString(),
        loading: false,
      ));
      if (wasLoading) {
        Future.microtask(() => refreshEntries());
      }
    }
  }

  void refreshEntries() {
    emit(state.copyWith(loading: true));
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'type': 'get_threat_intel_entries'}),
    );
  }

  void refreshStatus() {
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'type': 'get_threat_intel_status'}),
    );
  }

  void requestRefreshFeeds() {
    emit(state.copyWith(loading: true));
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'type': 'refresh_threat_intel'}),
    );
  }

  @override
  Future<void> close() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
