import 'dart:convert';

import 'package:intl/intl.dart';

/// Reads JWT `exp` claim without verifying signature (display only).
DateTime? readJwtExpiryUtc(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    var payload = parts[1];
    final mod = payload.length % 4;
    if (mod > 0) payload += '=' * (4 - mod);
    final jsonStr = utf8.decode(base64Url.decode(payload));
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final exp = map['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    }
  } catch (_) {}
  return null;
}

String formatJwtExpiryLine(String? token) {
  final exp = readJwtExpiryUtc(token);
  if (exp == null) return 'JWT expiry: unknown';
  final local = exp.toLocal();
  return 'JWT expires: ${DateFormat.yMMMd().add_jm().format(local)}';
}
