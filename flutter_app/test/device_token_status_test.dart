import 'package:dio/dio.dart';
import 'package:endpoint_monitor/utils/device_token_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deviceTokenStatusFromHttp', () {
    test('200 is valid', () {
      expect(deviceTokenStatusFromHttp(200), DeviceTokenStatus.valid);
    });

    test('401 is revoked; 403 is not treated as unpaired', () {
      expect(deviceTokenStatusFromHttp(401), DeviceTokenStatus.revoked);
      expect(deviceTokenStatusFromHttp(403), DeviceTokenStatus.unknown);
    });

    test('missing or other codes are unknown', () {
      expect(deviceTokenStatusFromHttp(null), DeviceTokenStatus.unknown);
      expect(deviceTokenStatusFromHttp(500), DeviceTokenStatus.unknown);
    });
  });

  group('storedTokenConnectDecision', () {
    test('revoked token must not connect and must show pairing again', () {
      final decision = storedTokenConnectDecision(DeviceTokenStatus.revoked);
      expect(decision.proceedWithToken, isFalse);
      expect(decision.clearStoredToken, isTrue);
      expect(decision.errorMessage, kDeviceUnpairedMessage);
    });

    test('valid token proceeds', () {
      final decision = storedTokenConnectDecision(DeviceTokenStatus.valid);
      expect(decision.proceedWithToken, isTrue);
      expect(decision.clearStoredToken, isFalse);
      expect(decision.errorMessage, isNull);
    });

    test('unknown status still attempts the stored token', () {
      final decision = storedTokenConnectDecision(DeviceTokenStatus.unknown);
      expect(decision.proceedWithToken, isTrue);
      expect(decision.clearStoredToken, isFalse);
    });
  });

  group('deviceTokenStatusFromConnectionError', () {
    test('401 handshake is revoked', () {
      expect(
        deviceTokenStatusFromConnectionError(
          Exception('WebSocketException: HTTP 401 Unauthorized'),
        ),
        DeviceTokenStatus.revoked,
      );
    });

    test('generic disconnect is unknown', () {
      expect(
        deviceTokenStatusFromConnectionError(Exception('Connection reset')),
        DeviceTokenStatus.unknown,
      );
    });
  });

  group('probeDeviceToken', () {
    test('maps 401 from the agent to revoked', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:5000'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 401),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final status = await probeDeviceToken('127.0.0.1:5000', 'dead-token', dio: dio);
      expect(status, DeviceTokenStatus.revoked);
    });
  });
}
