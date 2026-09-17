import 'package:shared_preferences/shared_preferences.dart';

import 'connect_path.dart';

const legacySavedHostKey = 'em_connect_saved_host';
const legacyRememberConnectKey = 'em_remember_connect';

/// SharedPreferences key for a remembered host on [path].
String savedHostPrefKey(ConnectPath path) => switch (path) {
      ConnectPath.wifi => 'em_connect_saved_host_wifi',
      ConnectPath.tailscale => 'em_connect_saved_host_tailscale',
    };

/// SharedPreferences key for the remember checkbox on [path].
String rememberConnectPrefKey(ConnectPath path) => switch (path) {
      ConnectPath.wifi => 'em_remember_connect_wifi',
      ConnectPath.tailscale => 'em_remember_connect_tailscale',
    };

/// Loads remembered hosts and checkbox state for each connect path.
ConnectPersistedPaths loadConnectPersistedPaths(SharedPreferences prefs) {
  return ConnectPersistedPaths(
    savedHosts: {
      for (final path in ConnectPath.values)
        path: _nonEmpty(prefs.getString(savedHostPrefKey(path))),
    },
    rememberAddress: {
      for (final path in ConnectPath.values)
        path: prefs.getBool(rememberConnectPrefKey(path)) ?? true,
    },
  );
}

/// Moves legacy single-path prefs into per-path keys (one-time).
Future<void> migrateLegacyConnectPrefs(
  SharedPreferences prefs, {
  String? secureHost,
}) async {
  final legacyHost = _nonEmpty(prefs.getString(legacySavedHostKey));
  final legacyRemember = prefs.getBool(legacyRememberConnectKey);
  final legacyPathPref = connectPathFromPref(prefs.getString(kConnectPathPrefKey));

  if (legacyHost != null) {
    final path = legacyPathPref ?? inferConnectPathFromHost(legacyHost);
    if (_nonEmpty(prefs.getString(savedHostPrefKey(path))) == null) {
      await prefs.setString(savedHostPrefKey(path), legacyHost);
    }
    if (legacyRemember != null &&
        prefs.getBool(rememberConnectPrefKey(path)) == null) {
      await prefs.setBool(rememberConnectPrefKey(path), legacyRemember);
    }
    await prefs.remove(legacySavedHostKey);
    if (legacyRemember != null) {
      await prefs.remove(legacyRememberConnectKey);
    }
  }

  final hostFromSecure = _nonEmpty(secureHost);
  if (hostFromSecure == null) return;

  final hasAnyPathHost = ConnectPath.values.any(
    (path) => _nonEmpty(prefs.getString(savedHostPrefKey(path))) != null,
  );
  if (hasAnyPathHost) return;

  final path = legacyPathPref ?? inferConnectPathFromHost(hostFromSecure);
  await prefs.setString(savedHostPrefKey(path), hostFromSecure);
  if (prefs.getBool(rememberConnectPrefKey(path)) == null) {
    await prefs.setBool(rememberConnectPrefKey(path), true);
  }
}

/// Address to pre-fill when opening a guided connect page.
String? connectAddressForPath(
  ConnectPath path,
  ConnectPersistedPaths persisted,
) {
  if (!(persisted.rememberAddress[path] ?? true)) return null;
  return persisted.savedHosts[path];
}

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

/// Remembered connect state loaded from SharedPreferences.
class ConnectPersistedPaths {
  const ConnectPersistedPaths({
    required this.savedHosts,
    required this.rememberAddress,
  });

  final Map<ConnectPath, String?> savedHosts;
  final Map<ConnectPath, bool> rememberAddress;
}
