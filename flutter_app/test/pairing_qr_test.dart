import 'dart:convert';

import 'package:endpoint_monitor/connect/connect_guide.dart';
import 'package:endpoint_monitor/connect/pairing_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final futureExpiry = DateTime.utc(2030, 1, 1);
  final pastExpiry = DateTime.utc(2020, 1, 1);

  String sampleUri({
    String code = '123456',
    List<String>? hosts,
    DateTime? expiresAt,
  }) =>
      encodePairingQrUri(
        code: code,
        hosts: hosts ?? ['http://192.168.1.50:5000', 'http://100.64.0.5:5000'],
        expiresAtUtc: expiresAt ?? futureExpiry,
      );

  group('parsePairingQr', () {
    test('parses full endpointmonitor uri', () {
      final uri = sampleUri();
      final result = parsePairingQr(uri, now: DateTime.utc(2026, 1, 1));
      expect(result, isA<PairingQrParseOk>());
      final ok = result as PairingQrParseOk;
      expect(ok.data.code, '123456');
      expect(ok.data.hosts, [
        'http://192.168.1.50:5000',
        'http://100.64.0.5:5000',
      ]);
      expect(ok.data.expiresAt, futureExpiry);
    });

    test('parses raw base64url data without scheme', () {
      final uri = sampleUri();
      final data = uri.split('data=').last;
      final result = parsePairingQr(data, now: DateTime.utc(2026, 1, 1));
      expect(result, isA<PairingQrParseOk>());
    });

    test('rejects wrong scheme', () {
      final uri = sampleUri().replaceFirst('endpointmonitor', 'other');
      expect(parsePairingQr(uri), isA<PairingQrParseInvalid>());
    });

    test('rejects unsupported version', () {
      final uri = sampleUri();
      final data = uri.split('data=').last;
      final padded = data.replaceAll('-', '+').replaceAll('_', '/');
      final json = utf8.decode(base64.decode('$padded=='));
      final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
      map['v'] = 2;
      final bad =
          'endpointmonitor://pair?data=${base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '')}';
      expect(parsePairingQr(bad), isA<PairingQrParseInvalid>());
    });

    test('rejects invalid pairing code', () {
      final uri = sampleUri(code: '12ab56');
      expect(parsePairingQr(uri), isA<PairingQrParseInvalid>());
    });

    test('rejects empty hosts', () {
      final uri = sampleUri(hosts: []);
      expect(parsePairingQr(uri), isA<PairingQrParseInvalid>());
    });

    test('rejects non-http origins', () {
      final uri = sampleUri(hosts: ['ftp://192.168.1.50:5000']);
      expect(parsePairingQr(uri), isA<PairingQrParseInvalid>());
    });

    test('returns expired when expiresAt is in the past', () {
      final uri = sampleUri(expiresAt: pastExpiry);
      final result = parsePairingQr(uri, now: DateTime.utc(2026, 1, 1));
      expect(result, isA<PairingQrParseExpired>());
      expect((result as PairingQrParseExpired).expiresAt, pastExpiry);
    });

    test('expired message constant is user-facing', () {
      expect(kPairingQrExpiredMessage, contains('expired'));
      expect(kPairingQrInvalidMessage, contains('valid'));
    });
  });
}
