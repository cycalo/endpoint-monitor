import 'package:intl/intl.dart';

import '../models/ws_models.dart';

/// Filters out names with unresolved template placeholders.
bool isValidSoftwareName(String name) {
  final t = name.trim();
  if (t.isEmpty) return false;
  if (t.contains(r'${{') || t.contains(r'}}')) return false;
  return true;
}

/// Formats registry EstimatedSize (KB) for display.
String formatInstallSizeKb(int kb) {
  if (kb <= 0) return '—';
  const mb = 1024;
  const gb = mb * 1024;
  if (kb >= gb) {
    return '${(kb / gb).toStringAsFixed(1)} GB';
  }
  if (kb >= mb) {
    return '${(kb / mb).toStringAsFixed(1)} MB';
  }
  return '$kb KB';
}

/// Date line plus optional size, e.g. `12-Jan-2024 · 450 MB`.
String formatSoftwareDateAndSizeLine(String normalizedDate, int installSizeKb) {
  final size = formatInstallSizeKb(installSizeKb);
  final parts = <String>[];
  if (normalizedDate.isNotEmpty && normalizedDate != '—') {
    parts.add(normalizedDate);
  }
  if (size != '—') parts.add(size);
  if (parts.isEmpty) return '—';
  return parts.join(' · ');
}

String truncateVersion(String v, {int maxLen = 20}) {
  final t = v.trim();
  if (t.length <= maxLen) return t;
  return '${t.substring(0, maxLen)}…';
}

/// Card list row: vendor · version (version truncated). Date is shown separately — never here.
String buildSoftwareCardVendorVersionLine(InstalledSoftwareItem s, {int versionMaxLen = 12}) {
  final parts = <String>[];
  final vendor = s.vendor.trim();
  if (vendor.isNotEmpty) parts.add(vendor);
  final ver = truncateVersion(s.version, maxLen: versionMaxLen);
  if (ver.isNotEmpty) parts.add(ver);
  return parts.join(' · ');
}

DateTime? tryParseInstallDate(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;

  final iso = DateTime.tryParse(t);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(t);
  if (ymd != null) {
    return DateTime(
      int.parse(ymd[1]!),
      int.parse(ymd[2]!),
      int.parse(ymd[3]!),
    );
  }

  if (RegExp(r'^\d{8}$').hasMatch(t)) {
    return DateTime(
      int.parse(t.substring(0, 4)),
      int.parse(t.substring(4, 6)),
      int.parse(t.substring(6, 8)),
    );
  }

  try {
    return DateFormat('dd-MMM-yyyy', 'en_US').parseStrict(t);
  } catch (_) {}

  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(t);
  if (slash != null) {
    return DateTime(
      int.parse(slash[3]!),
      int.parse(slash[1]!),
      int.parse(slash[2]!),
    );
  }

  return null;
}

/// Normalized display: **DD-MMM-YYYY** (English month abbrev).
String normalizeInstallDateDisplay(String raw) {
  final d = tryParseInstallDate(raw);
  if (d == null) {
    final t = raw.trim();
    return t.isEmpty ? '—' : t;
  }
  return DateFormat('dd-MMM-yyyy', 'en_US').format(d);
}

bool isInstalledWithinLastDays(String raw, int days) {
  final d = tryParseInstallDate(raw);
  if (d == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final installDay = DateTime(d.year, d.month, d.day);
  final diff = today.difference(installDay).inDays;
  return diff >= 0 && diff <= days;
}

