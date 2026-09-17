import 'dart:async';

import 'package:endpoint_monitor/bloc/system_info_bloc.dart';
import 'package:endpoint_monitor/bloc/system_vitals_history_cubit.dart';
import 'package:endpoint_monitor/models/ws_models.dart';
import 'package:flutter_test/flutter_test.dart';

SystemInfo _testInfo({
  double cpu = 10,
  double ramUsed = 4,
  double ramTotal = 16,
  double sent = 1000,
  double recv = 2000,
}) {
  return SystemInfo(
    systemName: 'PC',
    cpuPercent: cpu,
    ramUsedGb: ramUsed,
    ramTotalGb: ramTotal,
    diskUsedGb: 100,
    diskTotalGb: 500,
    uptime: '1d 0h 0m',
    osCaption: 'Windows',
    osVersion: '11',
    osArchitecture: 'x64',
    patchLevel: '',
    domain: '',
    lastBootTime: '',
    loggedInUsers: const [],
    processCount: 100,
    networkConnectionCount: 50,
    eventsTodayCount: 0,
    networkBytesSentPerSec: sent,
    networkBytesReceivedPerSec: recv,
  );
}

void main() {
  group('SystemVitalsHistoryCubit', () {
    late StreamController<SystemInfoState> controller;
    late SystemVitalsHistoryCubit historyCubit;
    var requested = false;

    setUp(() {
      controller = StreamController<SystemInfoState>.broadcast();
      historyCubit = SystemVitalsHistoryCubit(
        controller.stream,
        requestLatest: () => requested = true,
      );
    });

    tearDown(() async {
      await historyCubit.close();
      await controller.close();
    });

    test('starts empty', () {
      expect(historyCubit.state.samples, isEmpty);
    });

    test('prime calls requestLatest', () {
      historyCubit.prime();
      expect(requested, isTrue);
    });

    test('ignores cache hydrates', () async {
      controller.add(
        SystemInfoState(info: _testInfo(cpu: 25), fromCache: true),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(historyCubit.state.samples, isEmpty);
    });

    test('appends live samples', () async {
      controller.add(
        SystemInfoState(info: _testInfo(cpu: 25), fromCache: false),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(historyCubit.state.samples.length, 1);
      expect(historyCubit.state.samples.first.cpuPercent, 25);
    });

    test('caps at kSystemVitalsHistoryCap', () async {
      for (var i = 0; i < kSystemVitalsHistoryCap + 5; i++) {
        controller.add(
          SystemInfoState(
            info: _testInfo(cpu: i.toDouble()),
            fromCache: false,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(historyCubit.state.samples.length, kSystemVitalsHistoryCap);
      expect(
        historyCubit.state.samples.last.cpuPercent,
        (kSystemVitalsHistoryCap + 4).toDouble(),
      );
    });
  });
}
