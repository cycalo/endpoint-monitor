import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/pop_transient_overlay_routes.dart';

/// When using [StatefulShellRoute.indexedStack], off-tab routes stay mounted, so
/// modal bottom sheets can remain visible after switching tabs. This mixin
/// listens to [GoRouter] and dismisses transient overlays when the active
/// location is no longer under [tabPathPrefix].
///
/// [tabPathPrefix] should be the shell branch root, e.g. `/events` or `/network`.
mixin AutoCloseTransientRoutesOnLeaveMixin<T extends StatefulWidget> on State<T> {
  String get tabPathPrefix;

  GoRouter? _router;

  void _onRouterNavigation() {
    if (!mounted) return;
    final loc = GoRouterState.of(context).matchedLocation;
    if (!loc.startsWith(tabPathPrefix)) {
      popTransientOverlayRoutes(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_onRouterNavigation);
      _router = router;
      _router!.routerDelegate.addListener(_onRouterNavigation);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouterNavigation);
    super.dispose();
  }
}
