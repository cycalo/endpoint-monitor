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

  static const _flaggedProcessStartedPrefix = 'Flagged process started:';

  /// Executable token after [message] prefix (basename, lowercased), or null if not a watchlist-style start line.
  static String? _executableFromFlaggedStartMessage(String message) {
    if (!message.startsWith(_flaggedProcessStartedPrefix)) return null;
    var rest = message.substring(_flaggedProcessStartedPrefix.length).trim();
    if (rest.isEmpty) return null;
    if (rest.contains('\\') || rest.contains('/')) {
      rest = rest.replaceAll('\\', '/').split('/').last.trim();
    }
    return rest.toLowerCase();
  }

  /// Whether [watchlistExecutableNamesLower] still includes this process (client watchlist; avoids notifying after unflag/removal lag).
  static bool _watchlistContainsExecutable(
    String message,
    Set<String> watchlistExecutableNamesLower,
  ) {
    final exe = _executableFromFlaggedStartMessage(message);
    if (exe == null) return true;
    return watchlistExecutableNamesLower.contains(exe);
  }

  static Future<void> maybeShowForAlert(
    Alert a, {
    required Set<String> watchlistExecutableNamesLower,
  }) async {
    if (!_ready) return;
    final p = await SharedPreferences.getInstance();
    final high = p.getBool(AppSettingsKeys.notifyHighSeverity) ?? true;
    final watch = p.getBool(AppSettingsKeys.notifyWatchlist) ?? true;
    final iso = p.getBool(AppSettingsKeys.notifyIsolation) ?? true;
    final soft = p.getBool(AppSettingsKeys.notifyNewSoftware) ?? true;

    final sev = a.severity.toLowerCase();
    var allow = false;

    if (a.type == 'flagged_process') {
      if (a.message.startsWith(_flaggedProcessStartedPrefix)) {
        if (!watch) return;
        if (!_watchlistContainsExecutable(
            a.message, watchlistExecutableNamesLower)) {
          return;
        }
        allow = true;
      } else {
        // e.g. encoded PowerShell — not tied to the executable watchlist.
        if (sev == 'high' && high) allow = true;
      }
    } else {
      if (sev == 'high' && high) allow = true;
      if (a.message.toLowerCase().contains('isolat') && iso) allow = true;
      if (a.type.contains('software') && soft) allow = true;
    }

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
