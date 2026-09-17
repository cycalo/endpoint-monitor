import 'package:endpoint_monitor/models/ws_models.dart';
import 'package:endpoint_monitor/utils/network_process_groups.dart';
import 'package:endpoint_monitor/utils/network_tcp_state.dart';
import 'package:flutter_test/flutter_test.dart';

NetworkConnection _conn({
  required int pid,
  required String processName,
  required String remoteAddress,
  int remotePort = 443,
  int localPort = 50000,
  String state = '5',
  String protocol = 'TCP',
}) {
  return NetworkConnection(
    pid: pid,
    processName: processName,
    localAddress: '192.168.1.71',
    localPort: localPort,
    remoteAddress: remoteAddress,
    remotePort: remotePort,
    protocol: protocol,
    state: state,
  );
}

void main() {
  group('normalizeCimTcpState', () {
    test('maps common CIM numeric states', () {
      expect(normalizeCimTcpState('2'), 'LISTEN');
      expect(normalizeCimTcpState('5'), 'ESTABLISHED');
      expect(normalizeCimTcpState('100'), 'BOUND');
    });
  });

  group('buildNetworkProcessGroups', () {
    test('merges multiple PIDs of same executable', () {
      final groups = buildNetworkProcessGroups([
        _conn(pid: 1, processName: 'Cursor.exe', remoteAddress: '1.2.3.4'),
        _conn(pid: 2, processName: 'cursor.exe', remoteAddress: '1.2.3.4'),
      ]);

      expect(groups, hasLength(1));
      expect(groups.first.processName, 'Cursor.exe');
      expect(groups.first.pids, {1, 2});
    });

    test('collapses same remote with different local ports', () {
      final groups = buildNetworkProcessGroups([
        _conn(
          pid: 1,
          processName: 'Cursor.exe',
          remoteAddress: '1.2.3.4',
          localPort: 10001,
        ),
        _conn(
          pid: 1,
          processName: 'Cursor.exe',
          remoteAddress: '1.2.3.4',
          localPort: 10002,
        ),
      ]);

      expect(groups.single.remotes, hasLength(1));
      expect(groups.single.remotes.single.socketCount, 2);
    });

    test('search helper matches remote IP', () {
      final groups = buildNetworkProcessGroups([
        _conn(pid: 1, processName: 'Cursor.exe', remoteAddress: '99.83.165.34'),
      ]);
      expect(networkGroupMatchesSearch(groups.single, '99.83'), isTrue);
      expect(networkGroupMatchesSearch(groups.single, 'notepad'), isFalse);
    });

    test('separates local binds from remotes', () {
      final groups = buildNetworkProcessGroups([
        _conn(
          pid: 1,
          processName: 'Cursor.exe',
          remoteAddress: '0.0.0.0',
          remotePort: 0,
          state: '100',
        ),
        _conn(pid: 1, processName: 'Cursor.exe', remoteAddress: '1.2.3.4'),
      ]);

      expect(groups.single.localBinds, hasLength(1));
      expect(groups.single.remotes, hasLength(1));
      expect(groups.single.establishedCount, 1);
    });
  });

  group('mergeFirewallBlockedProcessGroups', () {
    test('keeps a blocked app with no live sockets so it can be unblocked', () {
      final groups = mergeFirewallBlockedProcessGroups(
        groups: const [],
        blocks: const [
          FirewallProcessBlockInfo(
            processName: 'chrome.exe',
            direction: 'outbound',
          ),
        ],
        runningPidsByProcessName: {
          'chrome.exe': {4321},
        },
      );

      expect(groups, hasLength(1));
      expect(groups.single.processName, 'chrome.exe');
      expect(groups.single.pids, {4321});
      expect(groups.single.remotes, isEmpty);
      expect(groups.single.establishedCount, 0);
      expect(
        networkGroupVisibleInDefaultAppsView(
          groups.single,
          const ['chrome.exe'],
        ),
        isTrue,
      );
    });

    test('does not duplicate an app that still has sockets', () {
      final live = buildNetworkProcessGroups([
        _conn(pid: 9, processName: 'chrome.exe', remoteAddress: '1.2.3.4'),
      ]);
      final groups = mergeFirewallBlockedProcessGroups(
        groups: live,
        blocks: const [
          FirewallProcessBlockInfo(
            processName: 'chrome.exe',
            direction: 'outbound',
          ),
        ],
      );

      expect(groups, hasLength(1));
      expect(groups.single.pids, {9});
      expect(groups.single.establishedCount, 1);
    });

    test('default apps filter hides silent apps unless firewall-blocked', () {
      final silent = buildNetworkProcessGroups([
        _conn(
          pid: 1,
          processName: 'svchost.exe',
          remoteAddress: '0.0.0.0',
          remotePort: 0,
          state: '100',
        ),
      ]).single;
      expect(networkGroupVisibleInDefaultAppsView(silent, const []), isFalse);
      expect(
        networkGroupVisibleInDefaultAppsView(silent, const ['svchost.exe']),
        isTrue,
      );
    });
  });
}
