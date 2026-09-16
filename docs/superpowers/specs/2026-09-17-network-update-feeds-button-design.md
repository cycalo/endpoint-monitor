# Network Update Feeds Button Design

## Goal

Make the Network screen's idle **Update feeds** control clearly look tappable
while preserving unambiguous feedback during an active refresh.

## Design

- Change the threat-intelligence panel action from `FilledButton.tonal` to the
  standard primary `FilledButton`.
- Keep the existing full-width layout, label, and refresh callback.
- While no refresh is running, show **Update feeds** with the theme's primary
  filled-button colors and keep the action enabled.
- While a refresh is running, disable the action and show **Updating…**. The
  existing progress indicator remains visible.
- Rely on the application theme for enabled and disabled colors so the control
  remains consistent in light and dark modes.

## Scope

This change affects only the update action in `EmThreatIntelPanel`. Feed
refresh behavior, network requests, errors, panel layout, and other buttons are
unchanged.

## Validation

- Add or update a widget test that verifies the idle button is enabled and uses
  the primary filled-button variant.
- Verify the loading state disables the button and displays **Updating…**.
- Run Flutter analysis and the focused widget test.

