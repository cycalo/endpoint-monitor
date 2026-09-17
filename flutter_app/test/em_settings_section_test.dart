import 'package:endpoint_monitor/widgets/em_loading_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings section provides Material for interactive list tiles',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmSettingsSection(
            title: 'TEST',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Setting'),
              value: false,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
