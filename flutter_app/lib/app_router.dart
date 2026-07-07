import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bloc/connection_bloc.dart';
import 'models/ws_models.dart';
import 'router/go_router_refresh.dart';
import 'screens/alerts_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/controls_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/events_screen.dart';
import 'screens/firewall_screen.dart';
import 'screens/more_screen.dart';
import 'screens/network_connection_detail_screen.dart';
import 'screens/network_screen.dart';
import 'screens/paired_devices_screen.dart';
import 'screens/process_detail_screen.dart';
import 'screens/processes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/software_detail_screen.dart';
import 'screens/software_screen.dart';
import 'screens/watchlist_screen.dart';
import 'utils/pop_transient_overlay_routes.dart';
import 'widgets/em_loading_states.dart';

GoRouter createAppRouter(ConnectionBloc connectionBloc) {
  final refresh = GoRouterRefreshStream(connectionBloc.stream);
  return GoRouter(
    initialLocation: '/connect',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final connected = connectionBloc.state.isConnected;
      final loc = state.matchedLocation;
      final onConnect = loc == '/connect';
      final onDashboard = loc == '/dashboard';
      final canReconnect = connectionBloc.state.host != null &&
          connectionBloc.state.host!.trim().isNotEmpty;
      if (!connected && !onConnect) {
        if (canReconnect && !onDashboard) return '/dashboard';
        if (!canReconnect) return '/connect';
      }
      if (connected && onConnect) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        name: 'connect',
        path: '/connect',
        builder: (context, state) => const ConnectScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(shell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'dashboard',
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'processes',
                path: '/processes',
                builder: (context, state) => ProcessesScreen(
                  initialWatchFilter: state.uri.queryParameters['watch'],
                ),
                routes: [
                  GoRoute(
                    name: 'processDetail',
                    path: ':pid',
                    builder: (context, state) {
                      final pid =
                          int.tryParse(state.pathParameters['pid'] ?? '') ?? 0;
                      final ghost =
                          state.uri.queryParameters['ghost'] == '1';
                      return ProcessDetailScreen(
                        pid: pid,
                        isKilledGhostSnapshot: ghost,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'network',
                path: '/network',
                builder: (context, state) => NetworkScreen(
                  highlightThreats: state.uri.queryParameters['threats'] == '1',
                ),
                routes: [
                  GoRoute(
                    name: 'networkConnectionDetail',
                    path: 'detail',
                    builder: (context, state) {
                      final extra = state.extra;
                      if (extra is! NetworkConnection) {
                        return EmRouteErrorBody(
                          title: 'Connection unavailable',
                          message:
                              'Open a connection from the Network tab, then try again.',
                          onBack: () => context.pop(),
                        );
                      }
                      return NetworkConnectionDetailScreen(connection: extra);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'events',
                path: '/events',
                builder: (context, state) => EventsScreen(
                  focusHourUtc: state.uri.queryParameters['hour'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'more',
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        name: 'browser',
        path: '/browser',
        builder: (context, state) => const BrowserScreen(),
      ),
      GoRoute(
        name: 'software',
        path: '/software',
        builder: (context, state) => const SoftwareScreen(),
        routes: [
          GoRoute(
            name: 'softwareDetail',
            path: 'detail',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is! InstalledSoftwareItem) {
                return EmRouteErrorBody(
                  title: 'Software entry unavailable',
                  onBack: () => context.pop(),
                );
              }
              return SoftwareDetailScreen(item: extra);
            },
          ),
        ],
      ),
      GoRoute(
        name: 'alerts',
        path: '/alerts',
        builder: (context, state) => AlertsScreen(
          typeFilter: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        name: 'firewall',
        path: '/firewall',
        builder: (context, state) => const FirewallScreen(),
      ),
      GoRoute(
        name: 'controls',
        path: '/controls',
        builder: (context, state) => const ControlsScreen(),
      ),
      GoRoute(
        name: 'watchlist',
        path: '/watchlist',
        builder: (context, state) => const WatchlistScreen(),
      ),
      GoRoute(
        name: 'pairedDevices',
        path: '/paired-devices',
        builder: (context, state) => const PairedDevicesScreen(),
      ),
      GoRoute(
        name: 'settings',
        path: '/settings',
        builder: (context, state) => SettingsScreen(
          focusSection: state.uri.queryParameters['section'],
        ),
      ),
    ],
  );
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.15)),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.onSurface.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          animationDuration: const Duration(milliseconds: 280),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: shell.currentIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.memory_outlined),
              selectedIcon: Icon(Icons.memory_rounded),
              label: 'Processes',
            ),
            NavigationDestination(
              icon: Icon(Icons.lan_outlined),
              selectedIcon: Icon(Icons.lan_rounded),
              label: 'Network',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Events',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_open_rounded),
              selectedIcon: Icon(Icons.menu_rounded),
              label: 'More',
            ),
          ],
          onDestinationSelected: (index) {
            if (index != shell.currentIndex) {
              popTransientOverlayRoutes(context);
            }
            shell.goBranch(index);
          },
        ),
      ),
    );
  }
}
