# Endpoint Monitor — Staged Implementation Prompts
> Complete and test each stage before moving to the next.

---

## STAGE 1 — Kill Button & Flag Button Fixes (Processes Screen)

**Prompt 1A — Kill button colour and confirm dialog**

> "In the process card expanded view in ProcessesScreen, change the Kill button
> to use a red background colour (use the theme's error colour or Colors.red.shade700).
> The Kill button should always be red regardless of theme.
> Ensure the existing confirm dialog is present before executing kill_process —
> if there is no confirm dialog, add one now with the message:
> 'Kill [process name] (PID [pid])? This will immediately terminate the process
> and cannot be undone.' with a red confirm button labelled 'Kill' and a cancel button."

---

**Prompt 1B — Flag button stateful toggle with feedback**

> "Make the Flag button in the process card expanded view stateful based on
> WatchlistBloc.
>
> Behaviour:
> - On build, check WatchlistBloc state to see if this process name is already
>   in the flagged list (case insensitive match on process name)
> - If NOT flagged: show outlined flag icon with label 'Flag', neutral colour
> - If flagged: show filled flag icon with label 'Flagged', amber/orange colour
>   so it is visually distinct from the unflagged state
>
> On tap when NOT flagged:
> - Immediately send flag_process command via ProcessBloc.sendCommand
> - Optimistically update local state to show flagged appearance
> - Show snackbar: '[process name] added to watchlist'
>
> On tap when flagged:
> - Show a small confirm dialog: 'Remove [process name] from watchlist?'
>   with confirm and cancel buttons
> - On confirm: send unflag_process, update local state to unflagged, show
>   snackbar: '[process name] removed from watchlist'
>
> The flag state must update in real time — if WatchlistBloc state changes
> (e.g. process flagged from another screen), the button should reflect that
> without requiring a rebuild trigger."

**Prompt 1C — Virus Total Information Update**
> - Change the Reputation button to Virus Total, if thats all the scan is
> - The information contained in the virus total tray should be a bit more accurate and clear. If its clean its clean, if its unknown due to no scan results then its unknown. Give the virus total score as well
---

## STAGE 2 — Process Autocomplete in Firewall Screen

**Prompt 2 — Running process autocomplete for Block by Process**

> "Add process name autocomplete to the Process name text input on the Firewall
> screen's Block by Process tab.
>
> Implementation:
> - Listen to the text field's onChange
> - When the input has 2 or more characters, filter ProcessBloc's current process
>   list for processes whose name contains the typed string (case insensitive)
> - Show matching results as an overlay dropdown directly below the text input,
>   maximum 5 results
> - Each dropdown item shows: a small gear/process icon on the left, the process
>   name in bold, and the PID in muted text on the right
> - Tapping a suggestion fills the text input with the exact process name and
>   closes the dropdown
> - If no running processes match the typed string, show a single muted dropdown
>   item: 'No running processes match — process must be running for path lookup'
> - Dismiss the dropdown if the user taps outside it or clears the input below
>   2 characters
> - The dropdown should appear above the keyboard and not be obscured by it —
>   use an OverlayEntry or a suitable Flutter autocomplete widget
>
> Do not change any other behaviour of the Block by Process tab."

---

## STAGE 3 — Threat Intel UI Clarity (Settings Screen)

**Prompt 3 — Improve Threat Intel section in Settings**

> "Improve the Threat Intel section in the Settings screen with the following
> changes:
>
> 1. Change 'Blocklist entries: 664' to 'X known threat IPs monitored' —
>    use the word 'monitored' not 'blocked' since these are watched IPs that
>    trigger alerts, not IPs that are actively blocked by firewall rules
>
> 2. Change the raw ISO timestamp for last feed update to a human readable
>    relative format: 'Last updated: 2 hours ago' or 'Last updated: just now'
>    using the same relative time formatting used elsewhere in the app
>
> 3. Add a small muted info line below the IP count:
>    'Connections to these IPs trigger high severity alerts'
>    This clarifies to the user what the monitored list actually does
>
> 4. Show per-feed breakdown if available from get_threat_intel_status response:
>    Each feed on its own row with feed name and IP count e.g.
>    'Feodo Tracker · 312 IPs'
>    'Emerging Threats · 352 IPs'
>    Use muted text and a bullet separator, no extra cards needed"

---

## STAGE 4 — Dashboard Timeline Chart Fixes

**Prompt 4 — Timeline chart outlier capping and sizing**

> "Improve the Activity timeline chart on the Dashboard screen with the following
> changes:
>
> 1. Cap outlier values so a single spike does not flatten all other bars.
>    Calculate the 95th percentile value across all hourly buckets and all series.
>    Clamp any individual bar value to max 3x the median value for display purposes
>    only — the underlying data is unchanged. This prevents one anomalous hour
>    (e.g. emulator startup burst) from compressing all other activity to near zero.
>    Add a small footnote below the chart when capping is active:
>    'Some values capped for readability'
>
> 2. Reduce the chart card height by approximately 20% so it does not dominate
>    the dashboard. The chart should feel like a supplementary data panel, not
>    the hero element of the screen.
>
> 3. Move the instruction text 'Tap the red (alerts) segment to open Events for
>    that hour' into a collapsed info tooltip (ⓘ icon in the card header) rather
>    than static text below the chart. This frees up vertical space.
>
> 4. Make the X axis labels less dense — show every 4th hour label instead of
>    every hour to reduce crowding on small screens.
>
> Do not change the data fetching, refresh logic, or tap navigation behaviour."

---

## STAGE 5 — Controls Screen (New Feature)

**Prompt 5A — Windows service: remote controls commands**

> "Add remote system control commands to the Windows service ResponseCommandService.
>
> Implement the following new command types. Each must:
> - Require the existing Bearer auth (already enforced globally)
> - Log the action to AuditLog with timestamp and requesting IP
> - Return a command_result with success true/false and a message
>
> Commands:
>
> lock_screen:
>   Execute: rundll32.exe user32.dll,LockWorkStation
>   Via: Process.Start('rundll32.exe', 'user32.dll,LockWorkStation')
>   Success message: 'Screen locked'
>
> logoff_user:
>   Execute: shutdown /l
>   Success message: 'Current user logged off'
>
> restart_machine:
>   Accepts optional delaySeconds (int, default 0, max 300)
>   Execute: shutdown /r /t <delaySeconds> /c 'Endpoint Monitor remote restart'
>   Success message: 'Restart initiated in <delaySeconds> seconds'
>
> shutdown_machine:
>   Accepts optional delaySeconds (int, default 0, max 300)
>   Execute: shutdown /s /t <delaySeconds> /c 'Endpoint Monitor remote shutdown'
>   Success message: 'Shutdown initiated in <delaySeconds> seconds'
>
> sleep_machine:
>   Execute: rundll32.exe powrprof.dll,SetSuspendState 0,1,0
>   Success message: 'Sleep initiated'
>
> cancel_shutdown:
>   Execute: shutdown /a
>   Success message: 'Pending shutdown or restart cancelled'
>   On error (no shutdown pending): return success: false,
>   message: 'No pending shutdown to cancel'
>
> turn_off_display:
>   Execute: Send WM_SYSCOMMAND SC_MONITORPOWER message via P/Invoke
>   If P/Invoke is complex, use: nircmd.exe monitor off as fallback
>   and document in a code comment that nircmd must be present
>   Success message: 'Display turned off'
>
> All Process.Start calls must use elevated context — the service already runs
> as Administrator so this should work without additional elevation.
> Wrap each in try/catch and return success: false with the exception message
> on failure."

---

**Prompt 5B — Flutter: Controls screen UI**

> "Create a new Controls screen and add it to the app navigation.
>
> **Route:** /controls
> Add to app_router.dart as a pushed route (no bottom nav bar, back arrow).
> Add a 'Controls' row to the MoreScreen list between Firewall and Watchlist,
> with a computer/terminal icon and subtitle 'Remote system controls'.
>
> **Screen layout:**
> EmBrandAppBar with title 'Controls' and back arrow.
> Scrollable list of control cards grouped into sections.
>
> **Section 1 — SESSION**
> Card 1: Lock Screen
>   Icon: lock icon
>   Description: 'Lock the Windows session immediately'
>   Button: 'Lock Screen' — no confirm needed, low risk
>   On tap: send { type: 'lock_screen' }, show snackbar on command_result
>
> Card 2: Log Off
>   Icon: logout icon
>   Description: 'Log off the current Windows user'
>   Button: 'Log Off' — confirm dialog:
>   'Log off the current user on BIGGART? Unsaved work will be lost.'
>   Confirm button labelled 'Log Off' in amber
>
> **Section 2 — POWER**
> Card 3: Restart
>   Icon: restart/refresh icon
>   Description: 'Restart the monitored machine'
>   Delay selector before confirm: None (immediate) / 1 min / 5 min
>   Confirm dialog: 'Restart BIGGART? Machine will be unavailable while rebooting.
>   Monitoring will reconnect automatically after restart.'
>   Confirm button in amber labelled 'Restart'
>
> Card 4: Shutdown
>   Icon: power icon
>   Description: 'Shut down the monitored machine'
>   Delay selector: None / 1 min / 5 min
>   Confirm dialog: 'Shut down BIGGART? The monitoring connection will be lost.'
>   Confirm button in RED labelled 'Shut Down' — most destructive action
>
> Card 5: Sleep
>   Icon: moon/sleep icon
>   Description: 'Put the machine to sleep'
>   Button: 'Sleep' — confirm dialog:
>   'Put BIGGART to sleep? The monitoring connection will be lost until wake.'
>   Confirm in amber
>
> **Section 3 — DISPLAY**
> Card 6: Turn Off Display
>   Icon: monitor/screen icon
>   Description: 'Turn off the monitor without sleeping'
>   Button: 'Turn Off Display' — no confirm needed
>
> **Section 4 — CANCEL**
> Card 7: Cancel Pending Shutdown
>   Icon: cancel/x icon
>   Description: 'Cancel a pending restart or shutdown'
>   Button: 'Cancel Shutdown' — no confirm needed
>   This card should be visually muted/secondary compared to the others —
>   it is a safety action, not an initiation action
>
> **General behaviour:**
> - Use the machine hostname from SystemInfoBloc in all confirm dialog messages
>   so dialogs say 'Restart BIGGART?' not 'Restart machine?'
> - Each card shows a loading spinner on its button while waiting for command_result
> - On success: show snackbar with the success message from command_result
> - On failure: show red snackbar with the error message
> - All cards should be disabled with a muted appearance when ConnectionBloc
>   is not connected
> - Destructive actions (shutdown, logoff, restart) use a double confirmation:
>   first tap opens a bottom sheet explaining the action, second tap is the
>   red/amber confirm button
>
> **Visual design:**
> Cards should have a subtle left border colour coding:
> - Session controls: cyan border
> - Power controls: amber border (restart/sleep) and red border (shutdown)
> - Display controls: blue border
> - Cancel: grey border
> This gives immediate visual hierarchy between safe and destructive actions."

---

## Testing Order

After implementing each stage, test in this order before moving on:

| Stage | What to verify |
|-------|---------------|
| 1A | Kill button is red, confirm dialog appears before kill executes |
| 1B | Flag shows amber when active, snackbar appears, unflag works with confirm |
| 2 | Type 2+ chars in firewall process input, suggestions appear, tap fills field |
| 3 | Settings shows 'monitored' not 'blocked', relative timestamp, per-feed breakdown |
| 4 | Chart no longer has single dominant spike, height is reduced, axis labels readable |
| 5A | Each command executes on the PC, audit log entries created, errors handled |
| 5B | Controls screen accessible from More, all confirms fire, hostname shows in dialogs |

---