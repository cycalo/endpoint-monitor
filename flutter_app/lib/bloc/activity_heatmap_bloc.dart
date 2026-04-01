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
  });

  final List<ActivityHeatmapBucket> buckets;
  final bool loading;
  final String? generatedAtIso;

  ActivityHeatmapState copyWith({
    List<ActivityHeatmapBucket>? buckets,
    bool? loading,
    String? generatedAtIso,
  }) =>
      ActivityHeatmapState(
        buckets: buckets ?? this.buckets,
        loading: loading ?? this.loading,
        generatedAtIso: generatedAtIso ?? this.generatedAtIso,
      );

  @override
  List<Object?> get props => [buckets, loading, generatedAtIso];
}

class ActivityHeatmapBloc extends Cubit<ActivityHeatmapState> {
  ActivityHeatmapBloc() : super(const ActivityHeatmapState(loading: true)) {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  Timer? _refreshTimer;

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  void refresh({int hours = 24}) {
    emit(const ActivityHeatmapState(loading: true));
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({'type': 'get_timeline', 'hours': hours}),
    );
  }

  void _onData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type']?.toString() != 'timeline') return;
    final raw = m['data'];
    if (raw is! Map) return;
    final bucketsRaw = raw['buckets'];
    if (bucketsRaw is! List) return;
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
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    return super.close();
  }
}
