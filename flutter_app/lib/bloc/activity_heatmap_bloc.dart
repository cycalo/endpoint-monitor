import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ActivityHeatmapBucket extends Equatable {
  const ActivityHeatmapBucket({
    required this.hourIndex,
    required this.hourStartUtcIso,
    required this.activityLevel,
    required this.hasAlert,
  });

  final int hourIndex;
  final String hourStartUtcIso;
  final int activityLevel;
  final bool hasAlert;

  @override
  List<Object?> get props =>
      [hourIndex, hourStartUtcIso, activityLevel, hasAlert];
}

class ActivityHeatmapState extends Equatable {
  const ActivityHeatmapState({
    this.buckets = const [],
    this.loading = false,
    this.generatedAtIso,
    this.loadError,
  });

  final List<ActivityHeatmapBucket> buckets;
  final bool loading;
  final String? generatedAtIso;
  final String? loadError;

  ActivityHeatmapState copyWith({
    List<ActivityHeatmapBucket>? buckets,
    bool? loading,
    String? generatedAtIso,
    String? loadError,
    bool clearLoadError = false,
  }) =>
      ActivityHeatmapState(
        buckets: buckets ?? this.buckets,
        loading: loading ?? this.loading,
        generatedAtIso: generatedAtIso ?? this.generatedAtIso,
        loadError: clearLoadError ? null : (loadError ?? this.loadError),
      );

  @override
  List<Object?> get props => [buckets, loading, generatedAtIso, loadError];
}

class ActivityHeatmapBloc extends Cubit<ActivityHeatmapState> {
  ActivityHeatmapBloc() : super(const ActivityHeatmapState()) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  Timer? _refreshTimer;
  Timer? _loadTimeout;
  static const _loadTimeoutDuration = Duration(seconds: 20);

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  void refresh({int hours = 24}) {
    _loadTimeout?.cancel();
    emit(ActivityHeatmapState(loading: true, buckets: state.buckets));
    _loadTimeout = Timer(_loadTimeoutDuration, () {
      if (isClosed || !state.loading) return;
      emit(state.copyWith(
        loading: false,
        loadError: 'Timeline request timed out. Pull to refresh.',
      ));
    });
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'type': 'get_timeline', 'hours': hours}),
    );
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    final t = m['type']?.toString();

    if (t == 'command_result') {
      final cmd = m['command']?.toString();
      if (cmd != 'get_timeline') return;
      _loadTimeout?.cancel();
      if (m['success'] == true) return;
      emit(state.copyWith(
        loading: false,
        loadError: m['message']?.toString() ?? 'Could not load timeline.',
      ));
      return;
    }

    if (t != 'timeline') return;
    _loadTimeout?.cancel();
    final raw = m['data'];
    if (raw is! Map) {
      emit(state.copyWith(
        loading: false,
        loadError: 'Unexpected timeline payload.',
      ));
      return;
    }
    final bucketsRaw = raw['buckets'];
    if (bucketsRaw is! List) {
      emit(state.copyWith(
        loading: false,
        loadError: 'Unexpected timeline payload.',
      ));
      return;
    }
    final list = <ActivityHeatmapBucket>[];
    for (final e in bucketsRaw) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      final start = row['hourStartUtc']?.toString() ??
          row['hourStart']?.toString() ??
          '';
      list.add(ActivityHeatmapBucket(
        hourIndex: (row['hour'] as num?)?.toInt() ?? list.length,
        hourStartUtcIso: start,
        activityLevel: (row['activityLevel'] as num?)?.toInt() ?? 0,
        hasAlert: row['hasAlert'] == true,
      ));
    }
    list.sort((a, b) => a.hourIndex.compareTo(b.hourIndex));
    final gen = raw['generatedAt']?.toString();
    emit(ActivityHeatmapState(
      buckets: list,
      loading: false,
      generatedAtIso: gen,
    ));
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    _loadTimeout?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
