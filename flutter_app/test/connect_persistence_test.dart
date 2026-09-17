import 'package:endpoint_monitor/connect/connect_path.dart';
import 'package:endpoint_monitor/connect/connect_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('connectAddressForPath', () {
    test('returns saved host only for matching path when remember is on', () {
      const persisted = ConnectPersistedPaths(
        savedHosts: {
          ConnectPath.wifi: '192.168.1.71',
          ConnectPath.tailscale: '100.64.0.5',
        },
        rememberAddress: {
          ConnectPath.wifi: true,
          ConnectPath.tailscale: true,
        },
      );

      expect(
        connectAddressForPath(ConnectPath.wifi, persisted),
        '192.168.1.71',
      );
      expect(
        connectAddressForPath(ConnectPath.tailscale, persisted),
        '100.64.0.5',
      );
    });

    test('returns null when remember is off for that path', () {
      const persisted = ConnectPersistedPaths(
        savedHosts: {
          ConnectPath.wifi: '192.168.1.71',
          ConnectPath.tailscale: null,
        },
        rememberAddress: {
          ConnectPath.wifi: false,
          ConnectPath.tailscale: true,
        },
      );

      expect(connectAddressForPath(ConnectPath.wifi, persisted), isNull);
    });
  });

  group('migrateLegacyConnectPrefs', () {
    test('moves legacy saved host into wifi path when inferred', () async {
      SharedPreferences.setMockInitialValues({
        legacySavedHostKey: '192.168.1.71',
        legacyRememberConnectKey: true,
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyConnectPrefs(prefs);

      expect(prefs.getString(savedHostPrefKey(ConnectPath.wifi)), '192.168.1.71');
      expect(prefs.getBool(rememberConnectPrefKey(ConnectPath.wifi)), isTrue);
      expect(prefs.getString(legacySavedHostKey), isNull);
      expect(prefs.getString(savedHostPrefKey(ConnectPath.tailscale)), isNull);
    });

    test('moves legacy saved host into tailscale path when host is 100.x', () async {
      SharedPreferences.setMockInitialValues({
        legacySavedHostKey: '100.64.0.5',
      });
      final prefs = await SharedPreferences.getInstance();

      await migrateLegacyConnectPrefs(prefs);

      expect(
        prefs.getString(savedHostPrefKey(ConnectPath.tailscale)),
        '100.64.0.5',
      );
      expect(prefs.getString(savedHostPrefKey(ConnectPath.wifi)), isNull);
    });
  });
}
