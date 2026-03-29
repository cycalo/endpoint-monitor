import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ws_models.dart';
import '../settings/app_settings_keys.dart';

/// Optional local notifications for incoming alerts (respects Settings toggles).
abstract final class AlertNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      'em_alerts',
      'Security alerts',
      description: 'Endpoint Monitor security alerts',
      importance: Importance.high,
    ));
    _ready = true;
  }

  static Future<void> maybeShowForAlert(Alert a) async {
    if (!_ready) return;
    final p = await SharedPreferences.getInstance();
    final high = p.getBool(AppSettingsKeys.notifyHighSeverity) ?? true;
    final watch = p.getBool(AppSettingsKeys.notifyWatchlist) ?? true;
    final iso = p.getBool(AppSettingsKeys.notifyIsolation) ?? true;
    final soft = p.getBool(AppSettingsKeys.notifyNewSoftware) ?? true;

    var allow = false;
    if (a.severity.toLowerCase() == 'high' && high) allow = true;
    if (a.type == 'flagged_process' && watch) allow = true;
    if (a.message.toLowerCase().contains('isolat') && iso) allow = true;
    if (a.type.contains('software') && soft) allow = true;

    if (!allow) return;

    await _plugin.show(
      a.id.hashCode,
      'Endpoint Monitor',
      a.message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'em_alerts',
          'Security alerts',
          channelDescription: 'High-priority monitoring alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
