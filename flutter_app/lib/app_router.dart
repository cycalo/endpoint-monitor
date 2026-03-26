import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bloc/connection_bloc.dart';
import 'models/ws_models.dart';
import 'router/go_router_refresh.dart';
import 'screens/alerts_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/events_screen.dart';
import 'screens/firewall_screen.dart';
import 'screens/more_screen.dart';
import 'screens/network_connection_detail_screen.dart';
import 'screens/network_screen.dart';
import 'screens/process_detail_screen.dart';
import 'screens/processes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/software_detail_screen.dart';
import 'screens/software_screen.dart';
import 'screens/watchlist_screen.dart';

GoRouter createAppRouter(ConnectionBloc connectionBloc) {
  final refresh = GoRouterRefreshStream(connectionBloc.stream);
  return GoRouter(
    initialLocation: '/connect',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final connected = connectionBloc.state.isConnected;
      final loc = state.matchedLocation;
      final onConnect = loc == '/connect';
      if (!connected && !onConnect) return '/connect';
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
                builder: (context, state) => const ProcessesScreen(),
                routes: [
                  GoRoute(
                    name: 'processDetail',
                    path: ':pid',
                    builder: (context, state) {
                      final pid = int.tryParse(state.pathParameters['pid'] ?? '') ?? 0;
                      return ProcessDetailScreen(pid: pid);
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
                builder: (context, state) => const NetworkScreen(),
                routes: [
                  GoRoute(
                    name: 'networkConnectionDetail',
                    path: 'detail',
                    builder: (context, state) {
                      final extra = state.extra;
                      if (extra is! NetworkConnection) {
                        return const Scaffold(
                          body: Center(child: Text('Missing connection')),
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
                builder: (context, state) => const EventsScreen(),
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
                return const Scaffold(
                  body: Center(child: Text('Missing software entry')),
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
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        name: 'firewall',
        path: '/firewall',
        builder: (context, state) => const FirewallScreen(),
      ),
      GoRoute(
        name: 'watchlist',
        path: '/watchlist',
        builder: (context, state) => const WatchlistScreen(),
      ),
      GoRoute(
        name: 'settings',
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
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
            top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.15)),
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
          onDestinationSelected: shell.goBranch,
        ),
      ),
    );
  }
}
