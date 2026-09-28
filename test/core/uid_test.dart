import 'package:demo_nfc/core/uid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeUid', () {
    test('removes colons and converts to uppercase HEX', () {
      expect(normalizeUid('04:a1:b2:c3:d4:e5:f6'), equals('04A1B2C3D4E5F6'));
    });

    test('removes spaces, hyphens, and mixed casing', () {
      expect(normalizeUid('04 a1-b2 c3-d4 e5 f6'), equals('04A1B2C3D4E5F6'));
    });

    test('already normalized uppercase HEX remains unchanged', () {
      expect(normalizeUid('04A1B2C3D4E5F6'), equals('04A1B2C3D4E5F6'));
    });

    test('handles empty and special characters', () {
      expect(normalizeUid(''), equals(''));
      expect(normalizeUid(':::---   '), equals(''));
    });
  });
}
