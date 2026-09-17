import 'dart:convert';
import 'dart:typed_data';

import 'package:endpoint_monitor/bloc/controls_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed retake preserves the last successful screenshot', () async {
    final bloc = ControlsBloc();
    addTearDown(bloc.close);
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQ'
      'IHWP4z8DwHwAFgAI/ScL6WQAAAABJRU5ErkJggg==',
    );

    bloc.handleTaskData(<String, Object?>{
      'type': 'command_result',
      'command': 'capture_desktop_screenshot',
      'success': true,
      'data': <String, Object?>{'imageBase64': base64Encode(png)},
    });
    bloc.handleTaskData(<String, Object?>{
      'type': 'command_result',
      'command': 'capture_desktop_screenshot',
      'success': false,
      'message': 'screenshot_failed',
    });

    expect(bloc.state.screenshotPng, orderedEquals(png));
    expect(bloc.state.feedback?.success, isFalse);
    expect(bloc.state.feedback?.message, 'screenshot_failed');
  });

  test('successful response rejects data that is not a PNG', () async {
    final bloc = ControlsBloc();
    addTearDown(bloc.close);

    bloc.handleTaskData(<String, Object?>{
      'type': 'command_result',
      'command': 'capture_desktop_screenshot',
      'success': true,
      'data': <String, Object?>{
        'imageBase64': base64Encode(Uint8List.fromList(<int>[1, 2, 3])),
      },
    });

    expect(bloc.state.screenshotPng, isNull);
    expect(bloc.state.feedback?.success, isFalse);
    expect(bloc.state.feedback?.message, 'Screenshot data missing');
  });
}
