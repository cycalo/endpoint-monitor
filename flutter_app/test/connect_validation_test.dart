import 'package:endpoint_monitor/connect/connect_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateConnectAddress', () {
    test('rejects empty address', () {
      final result = validateConnectAddress('');
      expect(result, isA<ConnectValidationError>());
      expect((result as ConnectValidationError).message, contains('address'));
    });

    test('accepts non-empty address', () {
      expect(validateConnectAddress('192.168.1.50'), isA<ConnectValidationOk>());
    });
  });

  group('validatePairingCode', () {
    test('requires exactly six digits', () {
      expect(validatePairingCode('12345'), isA<ConnectValidationError>());
      expect(validatePairingCode('1234567'), isA<ConnectValidationError>());
      expect(validatePairingCode('12ab56'), isA<ConnectValidationError>());
    });

    test('accepts six digit code', () {
      expect(validatePairingCode('123456'), isA<ConnectValidationOk>());
    });
  });
}
