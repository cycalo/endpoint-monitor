import 'dart:convert';

import 'package:endpoint_monitor/connect/connect_guide.dart';
import 'package:endpoint_monitor/connect/connect_path.dart';
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
      final expiresAt = '${futureExpiry.year.toString().padLeft(4, '0')}-01-01T00:00:00Z';
      final payload = jsonEncode({
        'v': 2,
        'code': '123456',
        'hosts': ['http://192.168.1.50:5000'],
        'expiresAt': expiresAt,
      });
      final data = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
      expect(
        parsePairingQr('endpointmonitor://pair?data=$data'),
        isA<PairingQrParseInvalid>(),
      );
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

  group('hostsMatchingConnectPath', () {
    const hosts = [
      'http://192.168.1.50:5000',
      'http://100.64.0.5:5000',
    ];

    test('wifi keeps lan and drops tailscale', () {
      expect(
        hostsMatchingConnectPath(hosts, ConnectPath.wifi),
        ['http://192.168.1.50:5000'],
      );
    });

    test('tailscale keeps cgnat and drops lan', () {
      expect(
        hostsMatchingConnectPath(hosts, ConnectPath.tailscale),
        ['http://100.64.0.5:5000'],
      );
    });

    test('returns empty when qr has no hosts for path', () {
      expect(
        hostsMatchingConnectPath(['http://192.168.1.50:5000'], ConnectPath.tailscale),
        isEmpty,
      );
    });
  });
}
