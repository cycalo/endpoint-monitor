# Remove Dashboard 24H Activity

## Goal

Remove the 24H Activity feature completely because it is no longer needed.

## Scope

- Remove the activity heatmap card from the connected Dashboard.
- Remove Dashboard activity auto-refresh/bootstrap behavior.
- Remove the global activity heatmap bloc provider.
- Delete the now-unused activity heatmap bloc and widget.
- Update Dashboard copy and README text that refer to activity or the heatmap.

## Behavior

The Dashboard will show connection status followed by Threat Intel and the existing system metrics. No activity heatmap request or refresh timer will run.

Disconnected and offline Dashboard behavior remains unchanged.

## Verification

- Search for remaining activity heatmap symbols and user-facing 24H Activity text.
- Run Dart formatting on edited Dart files.
- Run Flutter static analysis and relevant tests.
