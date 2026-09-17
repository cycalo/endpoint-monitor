import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/ws_models.dart';
import '../utils/em_vital_band.dart';
import 'system_info_bloc.dart';

/// Maximum rolling samples retained (~10 min at 10s agent interval).
const int kSystemVitalsHistoryCap = 60;

/// One timestamped vitals sample for sparklines and hero waveform.
class SystemVitalsSample extends Equatable {
  const SystemVitalsSample({
    required this.at,
    required this.cpuPercent,
    required this.ramPercent,
    required this.bytesSentPerSec,
    required this.bytesReceivedPerSec,
  });

  final DateTime at;
  final double cpuPercent;
  final double ramPercent;
  final double bytesSentPerSec;
  final double bytesReceivedPerSec;

  @override
  List<Object?> get props => [
        at,
        cpuPercent,
        ramPercent,
        bytesSentPerSec,
        bytesReceivedPerSec,
      ];
}

class SystemVitalsHistoryState extends Equatable {
  const SystemVitalsHistoryState({this.samples = const []});

  final List<SystemVitalsSample> samples;

  SystemVitalsHistoryState copyWith({List<SystemVitalsSample>? samples}) =>
      SystemVitalsHistoryState(samples: samples ?? this.samples);

  @override
  List<Object?> get props => [samples];
}

/// Route-scoped rolling history fed by [SystemInfoBloc] live pushes only.
class SystemVitalsHistoryCubit extends Cubit<SystemVitalsHistoryState> {
  SystemVitalsHistoryCubit(
    Stream<SystemInfoState> systemInfoStream, {
    void Function()? requestLatest,
  })  : _requestLatest = requestLatest,
        super(const SystemVitalsHistoryState()) {
    _subscription = systemInfoStream.listen(_onSystemInfoState);
  }

  /// Convenience constructor for route wiring.
  factory SystemVitalsHistoryCubit.fromBloc(SystemInfoBloc bloc) {
    return SystemVitalsHistoryCubit(
      bloc.stream,
      requestLatest: bloc.requestLatest,
    );
  }

  final void Function()? _requestLatest;
  late final StreamSubscription<SystemInfoState> _subscription;
  DateTime? _lastSampleAt;
  double? _lastCpu;
  double? _lastRam;
  double? _lastSent;
  double? _lastRecv;

  /// Request an immediate snapshot and accept the next live push.
  void prime() {
    _requestLatest?.call();
  }

  void _onSystemInfoState(SystemInfoState state) {
    if (state.fromCache || state.info == null) return;
    _appendFromInfo(state.info!);
  }

  void _appendFromInfo(SystemInfo info) {
    final at = DateTime.now();
    final cpu = info.cpuPercent;
    final ram = emRamPercent(info.ramUsedGb, info.ramTotalGb);
    final sent = info.networkBytesSentPerSec;
    final recv = info.networkBytesReceivedPerSec;

    // Skip duplicate re-emits of the same payload within the same second.
    if (_lastSampleAt != null &&
        _lastCpu == cpu &&
        _lastRam == ram &&
        _lastSent == sent &&
        _lastRecv == recv &&
        at.difference(_lastSampleAt!).inSeconds < 2) {
      return;
    }

    _lastSampleAt = at;
    _lastCpu = cpu;
    _lastRam = ram;
    _lastSent = sent;
    _lastRecv = recv;

    final sample = SystemVitalsSample(
      at: at,
      cpuPercent: cpu,
      ramPercent: ram,
      bytesSentPerSec: sent,
      bytesReceivedPerSec: recv,
    );

    final next = [...state.samples, sample];
    if (next.length > kSystemVitalsHistoryCap) {
      emit(SystemVitalsHistoryState(
        samples: next.sublist(next.length - kSystemVitalsHistoryCap),
      ));
    } else {
      emit(SystemVitalsHistoryState(samples: next));
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
