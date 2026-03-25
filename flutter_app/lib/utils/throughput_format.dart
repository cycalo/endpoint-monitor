/// Converts raw bytes/sec from the agent to a short Mbps string for UI.
String formatMbpsFromBytesPerSec(double bytesPerSec) {
  final mbps = bytesPerSec * 8 / 1e6;
  if (mbps < 0.005) return '0.0';
  if (mbps < 10) return mbps.toStringAsFixed(2);
  return mbps.toStringAsFixed(1);
}
