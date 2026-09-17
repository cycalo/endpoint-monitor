import 'package:endpoint_monitor/bloc/threat_intel_bloc.dart';
import 'package:endpoint_monitor/widgets/em_threat_intel_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Update feeds uses the primary filled button color', (tester) async {
    final bloc = ThreatIntelBloc();
    addTearDown(bloc.close);
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          theme: theme,
          home: const Scaffold(body: EmThreatIntelPanel()),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find
          .ancestor(
            of: find.text('Update feeds'),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(material.color, theme.colorScheme.primary);
  });
}
