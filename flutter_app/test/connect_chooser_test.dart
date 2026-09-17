import 'package:endpoint_monitor/connect/connect_path.dart';
import 'package:endpoint_monitor/screens/connect_chooser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows both path cards and chooser copy', (tester) async {
    ConnectPath? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectChooser(
            onPathSelected: (path) => selected = path,
          ),
        ),
      ),
    );

    expect(find.text('Connect to your PC'), findsOneWidget);
    expect(find.text('How should this phone reach the PC?'), findsOneWidget);
    expect(find.text('This Wi-Fi'), findsOneWidget);
    expect(find.text('Away from home'), findsOneWidget);
    expect(find.text('Download Windows service'), findsOneWidget);
    expect(find.textContaining('Install Endpoint Monitor on the PC'), findsOneWidget);

    await tester.tap(find.text('This Wi-Fi'));
    await tester.pump();
    expect(selected, ConnectPath.wifi);
  });

  testWidgets('shows continue chip when saved host provided', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectChooser(
            savedHost: '192.168.1.50',
            savedPath: ConnectPath.wifi,
            onContinueSaved: () => continued = true,
            onPathSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Continue to 192.168.1.50'), findsOneWidget);
    await tester.tap(find.text('Continue to 192.168.1.50'));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('hides continue chip without saved host', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectChooser(
            onPathSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Continue to'), findsNothing);
  });
}
