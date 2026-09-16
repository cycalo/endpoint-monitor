import 'dart:convert';
import 'dart:typed_data';

import 'package:endpoint_monitor/bloc/connection_bloc.dart';
import 'package:endpoint_monitor/bloc/controls_bloc.dart';
import 'package:endpoint_monitor/bloc/system_info_bloc.dart';
import 'package:endpoint_monitor/screens/controls_screen.dart';
import 'package:endpoint_monitor/widgets/desktop_screenshot_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQ'
  'IHWP4z8DwHwAFgAI/ScL6WQAAAABJRU5ErkJggg==',
);

Widget _app({
  required Uint8List bytes,
  required bool retakePending,
  required VoidCallback? onRetake,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DesktopScreenshotPreview(
        bytes: bytes,
        retakePending: retakePending,
        onRetake: onRetake,
        onClose: () {},
        onDownload: () {},
        onShare: () {},
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Retake requests one fresh screenshot', (tester) async {
    var retakeCalls = 0;
    await tester.pumpWidget(
      _app(
        bytes: _png,
        retakePending: false,
        onRetake: () => retakeCalls++,
      ),
    );

    await tester.tap(find.byTooltip('Retake'));

    expect(retakeCalls, 1);
  });

  testWidgets('Retake is disabled and shows progress while pending',
      (tester) async {
    await tester.pumpWidget(
      _app(bytes: _png, retakePending: true, onRetake: () {}),
    );

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Retake'),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('preview displays replacement screenshot bytes', (tester) async {
    final replacement = Uint8List.fromList(<int>[..._png]);
    await tester.pumpWidget(
      _app(bytes: _png, retakePending: false, onRetake: () {}),
    );
    await tester.pumpWidget(
      _app(bytes: replacement, retakePending: false, onRetake: () {}),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as MemoryImage).bytes, same(replacement));
  });

  testWidgets('successful retake updates the existing dialog', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controls = ControlsBloc();
    final connection = ConnectionBloc(const FlutterSecureStorage());
    final systemInfo = SystemInfoBloc();
    addTearDown(controls.close);
    addTearDown(connection.close);
    addTearDown(systemInfo.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: controls),
          BlocProvider.value(value: connection),
          BlocProvider.value(value: systemInfo),
        ],
        child: const MaterialApp(home: ControlsScreen()),
      ),
    );

    controls.handleTaskData(<String, Object?>{
      'type': 'command_result',
      'command': 'capture_desktop_screenshot',
      'success': true,
      'data': <String, Object?>{'imageBase64': base64Encode(_png)},
    });
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    final replacement = Uint8List.fromList(<int>[..._png]);
    controls.handleTaskData(<String, Object?>{
      'type': 'command_result',
      'command': 'capture_desktop_screenshot',
      'success': true,
      'data': <String, Object?>{'imageBase64': base64Encode(replacement)},
    });
    await tester.pump();

    expect(find.byType(Dialog), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as MemoryImage).bytes, orderedEquals(replacement));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(controls.state.screenshotPng, isNull);
  });
}
