import 'package:flutter/material.dart';

/// Pops modal overlays (bottom sheets, dialogs) above the current branch route.
///
/// Uses the **root** navigator so sheets opened with [showModalBottomSheet] and
/// `useRootNavigator: true` are found even when nested navigators exist under
/// [StatefulShellRoute].
///
/// Does not pop normal page routes (e.g. detail pushes), so branch stacks stay intact.
void popTransientOverlayRoutes(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  // popUntil: predicate true => stop; false => pop and continue
  navigator.popUntil((route) {
    final r = route;
    if (r is ModalBottomSheetRoute) return false;
    if (r is DialogRoute) return false;
    if (r is RawDialogRoute) return false;
    return true;
  });
}
