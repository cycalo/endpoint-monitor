import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'endpoint_monitor_task_handler.dart';

@pragma('vm:entry-point')
void endpointMonitorStartCallback() {
  FlutterForegroundTask.setTaskHandler(EndpointMonitorTaskHandler());
}
