/// ISO 3166-1 alpha-2 to regional-indicator flag emoji; empty if invalid.
String countryCodeToFlagEmoji(String code) {
  if (code.length != 2) return '';
  final upper = code.toUpperCase();
  final a = upper.codeUnitAt(0);
  final b = upper.codeUnitAt(1);
  if (a < 0x41 || a > 0x5a || b < 0x41 || b > 0x5a) return '';
  return String.fromCharCode(0x1f1e6 + a - 0x41) + String.fromCharCode(0x1f1e6 + b - 0x41);
}
