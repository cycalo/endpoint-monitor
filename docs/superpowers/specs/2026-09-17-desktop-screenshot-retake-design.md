# Desktop Screenshot Retake Design

## Goal

Let the user request a fresh desktop screenshot from the existing preview
without closing and reopening it. This remains an explicit, one-shot action and
does not introduce polling or continuous capture.

## User Experience

- Add a **Retake** action beside the existing Download and Share actions.
- Keep the current screenshot visible while the replacement is being captured.
- Disable Retake and show progress while a screenshot command is pending.
- Replace the preview after a successful response.
- On failure, retain the previous screenshot and show the existing generic
  failure feedback.
- Download and Share always operate on the newest successful screenshot.

## Architecture and Data Flow

The Flutter client reuses the existing `capture_desktop_screenshot` WebSocket
command and response format. No Windows service or protocol changes are needed.

The controls screen tracks whether its screenshot dialog is open so subsequent
successful screenshot responses update that dialog instead of opening nested
dialogs. Screenshot state remains available for the dialog's lifetime and is
cleared when the dialog closes. A failed retake does not discard the last
successful image.

## Safety and Resource Use

Retake initiates exactly one capture per tap. The pending state prevents
concurrent captures, and no timers or background capture loops are added.
Existing authentication, image scaling, and command auditing remain unchanged.

## Validation

Widget and bloc tests cover:

- Retake sends one `capture_desktop_screenshot` command.
- Retake is disabled and indicates progress while pending.
- A successful retake updates the image without opening another dialog.
- A failed retake keeps the previous image and presents failure feedback.
- Closing the preview clears screenshot state.
