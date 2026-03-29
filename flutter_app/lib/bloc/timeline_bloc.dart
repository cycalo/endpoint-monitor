import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class TimelineHourBucket extends Equatable {
  const TimelineHourBucket({
    required this.hourStartIso,
    required this.processCreate,
    required this.networkConnect,
    required this.dnsQuery,
    required this.alerts,
  });

  final String hourStartIso;
  final int processCreate;
  final int networkConnect;
  final int dnsQuery;
  final int alerts;

  TimelineHourBucket copyWith({
    String? hourStartIso,
    int? processCreate,
    int? networkConnect,
    int? dnsQuery,
    int? alerts,
  }) =>
      TimelineHourBucket(
        hourStartIso: hourStartIso ?? this.hourStartIso,
        processCreate: processCreate ?? this.processCreate,
        networkConnect: networkConnect ?? this.networkConnect,
        dnsQuery: dnsQuery ?? this.dnsQuery,
        alerts: alerts ?? this.alerts,
      );

  @override
  List<Object?> get props =>
      [hourStartIso, processCreate, networkConnect, dnsQuery, alerts];
}

class TimelineState extends Equatable {
  const TimelineState({
    this.buckets = const [],
    this.loading = false,
    this.hours = 24,
  });

  final List<TimelineHourBucket> buckets;
  final bool loading;
  final int hours;

  TimelineState copyWith({
    List<TimelineHourBucket>? buckets,
    bool? loading,
    int? hours,
  }) =>
      TimelineState(
        buckets: buckets ?? this.buckets,
        loading: loading ?? this.loading,
        hours: hours ?? this.hours,
      );

  @override
  List<Object?> get props => [buckets, loading, hours];
}

class TimelineBloc extends Cubit<TimelineState> {
  TimelineBloc() : super(const TimelineState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  Timer? _refreshTimer;

  static DateTime? _parseIso(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s)?.toUtc();
  }

  static String _floorHourIso(DateTime utc) {
    final f = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    return f.toIso8601String();
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  void refresh({int hours = 24}) {
    emit(state.copyWith(loading: true, hours: hours));
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'type': 'get_timeline', 'hours': hours}),
    );
  }

  void _applyBuckets(List<TimelineHourBucket> list, {required int hours}) {
    emit(TimelineState(buckets: list, loading: false, hours: hours));
  }

  int? _indexForHourIso(String hourIso) {
    final target = DateTime.tryParse(hourIso)?.toUtc();
    if (target == null) return null;
    for (var i = 0; i < state.buckets.length; i++) {
      final b = DateTime.tryParse(state.buckets[i].hourStartIso)?.toUtc();
      if (b == null) continue;
      if (b.year == target.year &&
          b.month == target.month &&
          b.day == target.day &&
          b.hour == target.hour) {
        return i;
      }
    }
    return null;
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    final t = m['type']?.toString();

    if (t == 'timeline') {
      final raw = m['data'];
      if (raw is! Map) return;
      final bucketsRaw = raw['buckets'];
      if (bucketsRaw is! List) return;
      final list = <TimelineHourBucket>[];
      for (final e in bucketsRaw) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        list.add(TimelineHourBucket(
          hourStartIso: row['hourStart']?.toString() ?? '',
          processCreate: (row['processCreate'] as num?)?.toInt() ?? 0,
          networkConnect: (row['networkConnect'] as num?)?.toInt() ?? 0,
          dnsQuery: (row['dnsQuery'] as num?)?.toInt() ?? 0,
          alerts: (row['alerts'] as num?)?.toInt() ?? 0,
        ));
      }
      _applyBuckets(list, hours: state.hours);
      return;
    }

    if (t == 'sysmon_event') {
      final raw = m['data'];
      if (raw is! Map) return;
      final ev = Map<String, dynamic>.from(raw);
      final ts = _parseIso(ev['timestamp']?.toString());
      if (ts == null || state.buckets.isEmpty) return;
      final key = _floorHourIso(ts);
      final idx = _indexForHourIso(key);
      if (idx == null) return;
      final ty = ev['type']?.toString() ?? '';
      final b = state.buckets[idx];
      switch (ty) {
        case 'ProcessCreate':
          _replaceAt(idx, b.copyWith(processCreate: b.processCreate + 1));
          break;
        case 'NetworkConnect':
          _replaceAt(idx, b.copyWith(networkConnect: b.networkConnect + 1));
          break;
        case 'DnsQuery':
          _replaceAt(idx, b.copyWith(dnsQuery: b.dnsQuery + 1));
          break;
        default:
          break;
      }
      return;
    }

    if (t == 'alert') {
      if (state.buckets.isEmpty) return;
      final now = DateTime.now().toUtc();
      final key = _floorHourIso(now);
      final idx = _indexForHourIso(key);
      if (idx == null) return;
      final b = state.buckets[idx];
      _replaceAt(idx, b.copyWith(alerts: b.alerts + 1));
    }
  }

  void _replaceAt(int i, TimelineHourBucket b) {
    final next = List<TimelineHourBucket>.from(state.buckets);
    next[i] = b;
    emit(state.copyWith(buckets: next));
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
