# Desktop Screenshot Retake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit Retake action that refreshes the image inside the existing desktop screenshot preview.

**Architecture:** Keep the existing WebSocket command and Windows capture implementation. Make `ControlsScreen` coordinate one open preview dialog, retain the latest successful screenshot in `ControlsBloc`, and render the preview from bloc state so successful retakes update in place.

**Tech Stack:** Flutter, Dart, flutter_bloc, flutter_test

## Global Constraints

- Retake initiates exactly one `capture_desktop_screenshot` command per enabled tap.
- Do not add timers, polling, continuous capture, dependencies, or service protocol changes.
- Keep the previous successful image visible when a retake fails.
- Prevent concurrent captures through the existing pending command state.
- Preserve existing Download and Share behavior for the latest successful image.

---

### Task 1: Preserve the latest successful screenshot

**Files:**
- Modify: `flutter_app/lib/bloc/controls_bloc.dart:96-126`
- Create: `flutter_app/test/controls_bloc_test.dart`

**Interfaces:**
- Consumes: `ControlsBloc._onData(Object data)` command-result handling.
- Produces: screenshot failures update feedback and pending state without clearing `ControlsState.screenshotPng`.

- [ ] **Step 1: Write the failing bloc test**

Create a test-only entry point on `ControlsBloc` annotated with
`@visibleForTesting`, then test a successful screenshot followed by a failed
retake:

```dart
test('failed retake preserves the last successful screenshot', () {
  final bloc = ControlsBloc();
  addTearDown(bloc.close);
  final png = Uint8List.fromList(<int>[137, 80, 78, 71]);

  bloc.handleTaskDataForTest(<String, Object?>{
    'type': 'command_result',
    'command': 'capture_desktop_screenshot',
    'success': true,
    'data': <String, Object?>{'imageBase64': base64Encode(png)},
  });
  bloc.handleTaskDataForTest(<String, Object?>{
    'type': 'command_result',
    'command': 'capture_desktop_screenshot',
    'success': false,
    'message': 'screenshot_failed',
  });

  expect(bloc.state.screenshotPng, png);
  expect(bloc.state.feedback?.success, isFalse);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd flutter_app && flutter test test/controls_bloc_test.dart`

Expected: FAIL because `handleTaskDataForTest` is undefined or the failed
response clears the image.

- [ ] **Step 3: Implement screenshot retention**

Import `package:flutter/foundation.dart`, expose only the transport callback to
tests, and stop clearing screenshot state on failed capture:

```dart
@visibleForTesting
void handleTaskDataForTest(Object data) => _onData(data);
```

In the screenshot result branch, set `screenshotPng` only when decoding
succeeds. For failure or malformed data, omit `clearScreenshot: true` so
`copyWith` retains the previous successful value while still emitting generic
failure feedback.

- [ ] **Step 4: Run the bloc test**

Run: `cd flutter_app && flutter test test/controls_bloc_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the bloc behavior**

```bash
git add flutter_app/lib/bloc/controls_bloc.dart flutter_app/test/controls_bloc_test.dart
git commit -m "fix: preserve screenshot after failed retake"
```

---

### Task 2: Update the screenshot preview in place

**Files:**
- Modify: `flutter_app/lib/screens/controls_screen.dart:19-356`
- Create: `flutter_app/test/desktop_screenshot_preview_test.dart`

**Interfaces:**
- Consumes: `ControlsState.pending`, `ControlsState.screenshotPng`, and `ControlsBloc.send`.
- Produces: one coordinated screenshot dialog with Retake, Download, Share, and Close actions.

- [ ] **Step 1: Write failing widget tests**

Extract a public `DesktopScreenshotPreview` presentation widget from the dialog
body. Its constructor accepts `Uint8List bytes`, `bool retakePending`,
`VoidCallback? onRetake`, `VoidCallback onClose`, `VoidCallback onDownload`,
and `VoidCallback onShare`.

Test that:

```dart
expect(find.byTooltip('Retake'), findsOneWidget);
await tester.tap(find.byTooltip('Retake'));
expect(retakeCalls, 1);
```

Pump it again with `retakePending: true` and verify:

```dart
expect(
  tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh_rounded)).onPressed,
  isNull,
);
expect(find.byType(CircularProgressIndicator), findsOneWidget);
```

- [ ] **Step 2: Run the widget tests to verify they fail**

Run: `cd flutter_app && flutter test test/desktop_screenshot_preview_test.dart`

Expected: FAIL because `DesktopScreenshotPreview` and Retake do not exist.

- [ ] **Step 3: Implement dialog coordination**

Convert `ControlsScreen` to a `StatefulWidget` and track:

```dart
bool _screenshotDialogOpen = false;
```

On a successful screenshot:

```dart
if (_screenshotDialogOpen) return;
_screenshotDialogOpen = true;
await _showScreenshotPreview(context, bytes);
if (mounted) {
  context.read<ControlsBloc>().clearScreenshot();
  _screenshotDialogOpen = false;
}
```

Inside the dialog, use `BlocBuilder<ControlsBloc, ControlsState>` and choose
`state.screenshotPng ?? initialBytes`. Retake calls:

```dart
context.read<ControlsBloc>().send(
  const {'type': 'capture_desktop_screenshot'},
);
```

Disable Retake while
`state.pending.contains('capture_desktop_screenshot')`; show a compact progress
indicator in place of its refresh icon. Pass the currently rendered bytes to
Download and Share.

- [ ] **Step 4: Run focused tests**

Run:
`cd flutter_app && flutter test test/controls_bloc_test.dart test/desktop_screenshot_preview_test.dart`

Expected: PASS with no nested-dialog exceptions.

- [ ] **Step 5: Run static analysis and the full Flutter suite**

Run: `cd flutter_app && dart format lib/bloc/controls_bloc.dart lib/screens/controls_screen.dart test/controls_bloc_test.dart test/desktop_screenshot_preview_test.dart && flutter analyze && flutter test`

Expected: formatting succeeds, analysis reports no issues, and all tests pass.

- [ ] **Step 6: Commit the user interface**

```bash
git add flutter_app/lib/screens/controls_screen.dart flutter_app/test/desktop_screenshot_preview_test.dart
git commit -m "feat: add desktop screenshot retake action"
```
