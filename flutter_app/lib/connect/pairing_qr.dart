import 'dart:convert';

import 'connect_guide.dart';
import 'connect_path.dart';
import 'connect_validation.dart';

/// Parsed pairing payload from a desktop QR code.
class PairingQrData {
  const PairingQrData({
    required this.code,
    required this.hosts,
    required this.expiresAt,
  });

  final String code;
  final List<String> hosts;
  final DateTime expiresAt;
}

sealed class PairingQrParseResult {
  const PairingQrParseResult();
}

class PairingQrParseOk extends PairingQrParseResult {
  const PairingQrParseOk(this.data);

  final PairingQrData data;
}

class PairingQrParseInvalid extends PairingQrParseResult {
  const PairingQrParseInvalid(this.message);

  final String message;
}

class PairingQrParseExpired extends PairingQrParseResult {
  const PairingQrParseExpired(this.expiresAt);

  final DateTime expiresAt;
}

/// Parses a scanned QR payload (`endpointmonitor://pair?data=…` or raw base64url JSON).
PairingQrParseResult parsePairingQr(String raw, {DateTime? now}) {
  final dataParam = _extractDataPayload(raw);
  if (dataParam == null) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  Map<String, dynamic>? json;
  try {
    final bytes = _base64UrlDecode(dataParam);
    final decoded = utf8.decode(bytes);
    final parsed = jsonDecode(decoded);
    if (parsed is Map<String, dynamic>) {
      json = parsed;
    } else if (parsed is Map) {
      json = Map<String, dynamic>.from(parsed);
    }
  } catch (_) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  if (json == null) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  final version = json['v'];
  if (version != 1) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  final code = json['code']?.toString() ?? '';
  if (validatePairingCode(code) is ConnectValidationError) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  final hostsRaw = json['hosts'];
  if (hostsRaw is! List || hostsRaw.isEmpty) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  final hosts = <String>[];
  for (final entry in hostsRaw) {
    final origin = entry?.toString().trim() ?? '';
    if (!_isValidOrigin(origin)) {
      return const PairingQrParseInvalid(kPairingQrInvalidMessage);
    }
    hosts.add(origin);
  }

  final expiresRaw = json['expiresAt']?.toString();
  if (expiresRaw == null || expiresRaw.isEmpty) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  DateTime expiresAt;
  try {
    expiresAt = DateTime.parse(expiresRaw).toUtc();
  } catch (_) {
    return const PairingQrParseInvalid(kPairingQrInvalidMessage);
  }

  final clock = (now ?? DateTime.now()).toUtc();
  if (!expiresAt.isAfter(clock)) {
    return PairingQrParseExpired(expiresAt);
  }

  return PairingQrParseOk(
    PairingQrData(code: code, hosts: hosts, expiresAt: expiresAt),
  );
}

String? _extractDataPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      uri.scheme == 'endpointmonitor' &&
      uri.host == 'pair') {
    final data = uri.queryParameters['data'];
    if (data != null && data.isNotEmpty) return data;
  }

  const prefix = 'endpointmonitor://pair?data=';
  if (trimmed.toLowerCase().startsWith(prefix)) {
    return trimmed.substring(prefix.length);
  }

  if (!trimmed.contains(' ') && trimmed.length >= 16) {
    return trimmed;
  }
  return null;
}

bool _isValidOrigin(String origin) {
  final uri = Uri.tryParse(origin);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  return uri.host.isNotEmpty;
}

List<int> _base64UrlDecode(String input) {
  var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
  switch (normalized.length % 4) {
    case 2:
      normalized += '==';
      break;
    case 3:
      normalized += '=';
      break;
  }
  return base64.decode(normalized);
}

/// Encodes a pairing payload for tests and desktop parity checks.
String encodePairingQrUri({
  required String code,
  required List<String> hosts,
  required DateTime expiresAtUtc,
}) {
  final expiry = expiresAtUtc.toUtc();
  final expiresAt = '${expiry.year.toString().padLeft(4, '0')}-'
      '${expiry.month.toString().padLeft(2, '0')}-'
      '${expiry.day.toString().padLeft(2, '0')}T'
      '${expiry.hour.toString().padLeft(2, '0')}:'
      '${expiry.minute.toString().padLeft(2, '0')}:'
      '${expiry.second.toString().padLeft(2, '0')}Z';
  final payload = <String, dynamic>{
    'v': 1,
    'code': code,
    'hosts': hosts,
    'expiresAt': expiresAt,
  };
  final json = jsonEncode(payload);
  final data = base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  return 'endpointmonitor://pair?data=$data';
}

/// Hosts from a pairing QR that match [path] (LAN vs Tailscale).
List<String> hostsMatchingConnectPath(List<String> hosts, ConnectPath path) {
  return [
    for (final origin in hosts)
      if (inferConnectPathFromHost(origin) == path) origin,
  ];
}
