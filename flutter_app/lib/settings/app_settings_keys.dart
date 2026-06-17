import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences / secure keys for app-wide settings (Phase 1 roadmap).
abstract final class AppSettingsKeys {
  static const httpBase = 'em_http_base';
  static const rememberEndpoint = 'em_remember_endpoint';
  static const notifyHighSeverity = 'em_notify_high_severity';
  static const notifyWatchlist = 'em_notify_watchlist';
  static const notifyIsolation = 'em_notify_isolation';
  static const notifyNewSoftware = 'em_notify_new_software';
  static const noiseProcesses = 'em_noise_processes';
  static const eventsDefaultRange = 'em_events_default_range';
  static const eventsMaxLoad = 'em_events_max_load';
  static const showIpv6Network = 'em_show_ipv6_network';
  static const compactProcessCards = 'em_compact_process_cards';
  static const pinLockEnabled = 'em_pin_lock_enabled';
  static const autoLockTimeout = 'em_auto_lock_timeout';

  /// FlutterSecureStorage key for optional Groq API key (process AI explain).
  static const groqApiKey = 'groq_api_key';

  /// Comma-separated default noise list (lowercase .exe names).
  static const defaultNoiseCsv =
      'svchost.exe,msmpeng.exe,wmiprvse.exe,runtimebroker.exe,searchindexer.exe';

  /// `15m` | `1h` | `6h` | `all`
  static const defaultEventsRange = '1h';

  static const defaultEventsMaxLoad = 100;

  static Future<void> ensureDefaults(SharedPreferences p) async {
    if (!p.containsKey(notifyHighSeverity)) {
      await p.setBool(notifyHighSeverity, true);
    }
    if (!p.containsKey(notifyWatchlist)) {
      await p.setBool(notifyWatchlist, true);
    }
    if (!p.containsKey(notifyIsolation)) {
      await p.setBool(notifyIsolation, true);
    }
    if (!p.containsKey(notifyNewSoftware)) {
      await p.setBool(notifyNewSoftware, true);
    }
    if (!p.containsKey(noiseProcesses)) {
      await p.setString(noiseProcesses, defaultNoiseCsv);
    }
    if (!p.containsKey(eventsDefaultRange)) {
      await p.setString(eventsDefaultRange, defaultEventsRange);
    }
    if (!p.containsKey(eventsMaxLoad)) {
      await p.setInt(eventsMaxLoad, defaultEventsMaxLoad);
    }
    if (!p.containsKey(showIpv6Network)) {
      await p.setBool(showIpv6Network, false);
    }
    if (!p.containsKey(compactProcessCards)) {
      await p.setBool(compactProcessCards, false);
    }
    if (!p.containsKey(pinLockEnabled)) {
      await p.setBool(pinLockEnabled, false);
    }
    if (!p.containsKey(autoLockTimeout)) {
      await p.setString(autoLockTimeout, 'never');
    }
    if (!p.containsKey(rememberEndpoint)) {
      await p.setBool(rememberEndpoint, true);
    }
  }
}
