/// Human-readable relative time from an ISO-8601 UTC string (e.g. threat-intel last run).
String formatRelativeSinceUtcIso(String? isoUtc) {
  if (isoUtc == null || isoUtc.isEmpty) return '';
  final utc = DateTime.tryParse(isoUtc)?.toUtc();
  if (utc == null) return isoUtc;
  final now = DateTime.now().toUtc();
  var diff = now.difference(utc);
  if (diff.isNegative) diff = Duration.zero;
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 14) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
  final w = (diff.inDays / 7).floor();
  return '$w week${w == 1 ? '' : 's'} ago';
}
