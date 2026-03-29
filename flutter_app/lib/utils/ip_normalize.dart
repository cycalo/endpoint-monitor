/// Normalizes a remote IP for comparison and persistence (blocked-IP set).
String normalizeIpForBlockList(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  if (t.contains(':')) return t.toLowerCase();
  return t;
}
