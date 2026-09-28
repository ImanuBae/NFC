/// Normalizes any NFC UID string:
/// Removes colons, spaces, dashes, converts to uppercase HEX.
/// Example: "04:a1:b2:c3:d4:e5:f6" -> "04A1B2C3D4E5F6"
String normalizeUid(String rawUid) {
  return rawUid.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toUpperCase();
}
