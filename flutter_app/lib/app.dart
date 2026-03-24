import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';
import 'bloc/alerts_bloc.dart';
import 'bloc/browser_bloc.dart';
import 'bloc/connection_bloc.dart';
import 'bloc/events_bloc.dart';
import 'bloc/network_bloc.dart';
import 'bloc/process_bloc.dart';
import 'bloc/software_bloc.dart';
import 'bloc/system_info_bloc.dart';
import 'bloc/watchlist_bloc.dart';

class EndpointMonitorApp extends StatefulWidget {
  const EndpointMonitorApp({super.key, required this.notifications});

  final FlutterLocalNotificationsPlugin notifications;

  @override
  State<EndpointMonitorApp> createState() => _EndpointMonitorAppState();
}

class _EndpointMonitorAppState extends State<EndpointMonitorApp> {
  late final ConnectionBloc _connectionBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    const storage = FlutterSecureStorage();
    _connectionBloc = ConnectionBloc(storage);
    _router = createAppRouter(_connectionBloc);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectionBloc.add(const ConnectionStarted());
    });
  }

  @override
  void dispose() {
    _connectionBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _connectionBloc),
        BlocProvider(create: (_) => ProcessBloc()),
        BlocProvider(create: (_) => NetworkBloc()),
        BlocProvider(create: (_) => EventsBloc()),
        BlocProvider(create: (_) => SystemInfoBloc()),
        BlocProvider(create: (_) => AlertsBloc(widget.notifications)),
        BlocProvider(create: (_) => BrowserBloc()),
        BlocProvider(create: (_) => SoftwareBloc()),
        BlocProvider(create: (_) => WatchlistBloc()),
      ],
      child: BlocProvider(
        create: (_) {
          final cubit = ThemeCubit();
          cubit.load();
          return cubit;
        },
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Endpoint Monitor',
              theme: buildEndpointMonitorLightTheme(),
              darkTheme: buildEndpointMonitorDarkTheme(),
              themeMode: themeMode,
              routerConfig: _router,
              builder: (context, child) =>
                  WithForegroundTask(child: child ?? const SizedBox.shrink()),
            );
          },
        ),
      ),
    );
  }
}
