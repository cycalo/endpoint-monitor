import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/connection_bloc.dart';
import '../utils/agent_health.dart';
import '../utils/device_token_status.dart';
import '../utils/export_http_base.dart';
import 'connect_path.dart';
import 'connect_persistence.dart';

/// Same keys as [ConnectionBloc].
const kEmHost = 'em_host';
const kEmToken = 'em_token';

class ConnectSessionResult {
  const ConnectSessionResult._({
    required this.success,
    this.errorMessage,
    this.clearedStoredToken = false,
    this.obtainedNewToken = false,
  });

  final bool success;
  final String? errorMessage;
  final bool clearedStoredToken;
  final bool obtainedNewToken;

  factory ConnectSessionResult.success({bool obtainedNewToken = false}) =>
      ConnectSessionResult._(success: true, obtainedNewToken: obtainedNewToken);

  factory ConnectSessionResult.failure(
    String message, {
    bool clearedStoredToken = false,
  }) =>
      ConnectSessionResult._(
        success: false,
        errorMessage: message,
        clearedStoredToken: clearedStoredToken,
      );
}

/// Converts a QR `hosts` origin to the monitor host string used elsewhere.
String monitorHostFromOrigin(String origin) {
  final uri = Uri.parse(origin);
  if (uri.hasPort) {
    return '${uri.host}:${uri.port}';
  }
  return uri.host;
}

/// Probes [hosts] in order and returns the first reachable monitor host.
Future<String?> probeFirstReachableHost(List<String> hosts) async {
  for (final origin in hosts) {
    final host = monitorHostFromOrigin(origin);
    if (await probeAgentHealth(host)) {
      return host;
    }
  }
  return null;
}

/// Persists host and path for remembered connect (QR and manual when enabled).
Future<void> persistConnectHost(String host, ConnectPath path) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kConnectPathPrefKey, connectPathToPref(path));
  await prefs.setBool(rememberConnectPrefKey(path), true);
  await prefs.setString(savedHostPrefKey(path), host);
  const secure = FlutterSecureStorage();
  await secure.write(key: kEmHost, value: host);
}

/// Pairing code exchange — same contract as the manual connect screen.
Future<ConnectSessionResult> exchangePairingCode({
  required String host,
  required String code,
  FlutterSecureStorage? storage,
}) async {
  try {
    final base = httpBaseFromMonitorHost(host);
    final dio = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/pairing/complete',
      data: {
        'code': code,
        'deviceName': 'Flutter ${Platform.operatingSystem}',
      },
    );
    final token = response.data?['token']?.toString();
    if (token == null || token.isEmpty) {
      return ConnectSessionResult.failure('Pairing failed. Check the code and endpoint, then try again.');
    }
    final secure = storage ?? const FlutterSecureStorage();
    await secure.write(key: kEmToken, value: token);
    await secure.write(key: kEmHost, value: host);
    return ConnectSessionResult.success(obtainedNewToken: true);
  } catch (e) {
    return ConnectSessionResult.failure(pairingFailureMessage(e));
  }
}

/// Token probe, optional pairing, persist, and WebSocket connect request.
Future<ConnectSessionResult> completeConnectSession({
  required ConnectionBloc connectionBloc,
  required String host,
  required ConnectPath path,
  String? pairingCode,
  bool persistHost = true,
  FlutterSecureStorage? storage,
}) async {
  final secure = storage ?? const FlutterSecureStorage();
  var token = await secure.read(key: kEmToken) ?? '';

  if (token.isNotEmpty) {
    final decision =
        storedTokenConnectDecision(await probeDeviceToken(host, token));
    if (decision.clearStoredToken) {
      await secure.delete(key: kEmToken);
      token = '';
      return ConnectSessionResult.failure(
        decision.errorMessage ?? kDeviceUnpairedMessage,
        clearedStoredToken: true,
      );
    }
  }

  var obtainedNewToken = false;
  if (token.isEmpty) {
    final code = pairingCode?.trim() ?? '';
    if (code.isEmpty) {
      return ConnectSessionResult.failure('Enter the 6-digit pairing code from the PC.');
    }
    final pairResult = await exchangePairingCode(
      host: host,
      code: code,
      storage: secure,
    );
    if (!pairResult.success) {
      return pairResult;
    }
    obtainedNewToken = true;
    token = await secure.read(key: kEmToken) ?? '';
    if (token.isEmpty) {
      return ConnectSessionResult.failure('Pairing failed. Check the code and endpoint, then try again.');
    }
  }

  if (persistHost) {
    await persistConnectHost(host, path);
  }

  connectionBloc.add(ConnectionConnectRequested(host: host, token: token));
  return ConnectSessionResult.success(obtainedNewToken: obtainedNewToken);
}
