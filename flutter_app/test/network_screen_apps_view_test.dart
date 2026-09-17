import 'package:endpoint_monitor/models/ws_models.dart';
import 'package:endpoint_monitor/utils/network_process_groups.dart';
import 'package:endpoint_monitor/widgets/em_network_app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App card shows Block app and groups duplicate sockets',
      (tester) async {
    final connections = [
      NetworkConnection(
        pid: 1,
        processName: 'Cursor.exe',
        localAddress: '192.168.1.71',
        localPort: 10001,
        remoteAddress: '1.2.3.4',
        remotePort: 443,
        protocol: 'TCP',
        state: '5',
      ),
      NetworkConnection(
        pid: 2,
        processName: 'Cursor.exe',
        localAddress: '192.168.1.71',
        localPort: 10002,
        remoteAddress: '1.2.3.4',
        remotePort: 443,
        protocol: 'TCP',
        state: '5',
      ),
    ];

    final group = buildNetworkProcessGroups(connections).single;
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmNetworkAppCard(
            group: group,
            scheme: scheme,
            blockedMap: const {},
            processBlocked: false,
            processBlockDirection: null,
            threatLookup: (_) => null,
            rowIcon: (_) => Icons.hub_rounded,
            onBlockProcess: (_) async {},
            onUnblockProcess: (_) async {},
            onBlockIp: (_) async {},
            onUnblockIp: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Block app'), findsOneWidget);
    expect(find.text('Block connection'), findsNothing);
    expect(find.text('2 processes'), findsOneWidget);
  });
}
