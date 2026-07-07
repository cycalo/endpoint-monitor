import 'package:dio/dio.dart';

import 'export_http_base.dart';

/// Quick reachability check against the agent's unauthenticated health endpoint.
Future<bool> probeAgentHealth(String host) async {
  final base = httpBaseFromMonitorHost(host);
  final dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));
  try {
    final res = await dio.get<Map<String, dynamic>>('/health');
    return res.data?['ok'] == true;
  } catch (_) {
    return false;
  }
}

/// Maps agent pairing error codes to user-facing messages.
String pairingFailureMessage(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 429) {
      return 'Too many pairing attempts. Wait a minute and try again.';
    }
    final data = error.response?.data;
    if (data is Map) {
      final code = data['error']?.toString();
      switch (code) {
        case 'pairing_code_expired':
          return 'That code has expired. Generate a new one on the Windows PC.';
        case 'pairing_code_used':
          return 'That code was already used. Generate a new one on the Windows PC.';
        case 'pairing_code_not_found':
          return 'Code not recognized. Check the digits and try again.';
        case 'pepper_invalid':
          return 'The agent is not configured for pairing (missing server secret).';
        case 'pairing_failed':
          return 'Pairing failed. Check the code and endpoint, then try again.';
      }
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Could not reach the endpoint. Check the IP and that the agent is running.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not reach the endpoint. Check the IP, firewall, and that the agent is running.';
    }
  }
  return 'Pairing failed. Check the code and endpoint, then try again.';
}
