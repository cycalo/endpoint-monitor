import 'package:dio/dio.dart';

import 'export_http_base.dart';

/// Whether a stored device token is still accepted by the agent.
enum DeviceTokenStatus { valid, revoked, unknown }

const kDeviceUnpairedMessage =
    'This phone was unpaired on the PC. Enter a new 6-digit code.';

class StoredTokenConnectDecision {
  const StoredTokenConnectDecision({
    required this.proceedWithToken,
    this.clearStoredToken = false,
    this.errorMessage,
  });

  final bool proceedWithToken;
  final bool clearStoredToken;
  final String? errorMessage;
}

DeviceTokenStatus deviceTokenStatusFromHttp(int? statusCode) {
  if (statusCode == 401) {
    return DeviceTokenStatus.revoked;
  }
  if (statusCode != null && statusCode >= 200 && statusCode < 300) {
    return DeviceTokenStatus.valid;
  }
  return DeviceTokenStatus.unknown;
}

DeviceTokenStatus deviceTokenStatusFromConnectionError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('401') || text.contains('unauthorized')) {
    return DeviceTokenStatus.revoked;
  }
  return DeviceTokenStatus.unknown;
}

StoredTokenConnectDecision storedTokenConnectDecision(DeviceTokenStatus status) {
  switch (status) {
    case DeviceTokenStatus.revoked:
      return const StoredTokenConnectDecision(
        proceedWithToken: false,
        clearStoredToken: true,
        errorMessage: kDeviceUnpairedMessage,
      );
    case DeviceTokenStatus.valid:
    case DeviceTokenStatus.unknown:
      return const StoredTokenConnectDecision(proceedWithToken: true);
  }
}

/// Confirms a stored device token against the agent. Fail closed on 401/403.
Future<DeviceTokenStatus> probeDeviceToken(
  String host,
  String token, {
  Dio? dio,
}) async {
  if (token.isEmpty) return DeviceTokenStatus.unknown;

  final client = dio ??
      Dio(BaseOptions(
        baseUrl: httpBaseFromMonitorHost(host),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Authorization': 'Bearer $token'},
      ));

  try {
    final res = await client.get<dynamic>('/api/auth/devices');
    return deviceTokenStatusFromHttp(res.statusCode);
  } on DioException catch (e) {
    return deviceTokenStatusFromHttp(e.response?.statusCode);
  } catch (_) {
    return DeviceTokenStatus.unknown;
  }
}
