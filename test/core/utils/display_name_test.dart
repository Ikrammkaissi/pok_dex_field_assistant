import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/core/utils/display_name.dart';

void main() {
  group('toDisplayName', () {
    test('converts single word', () {
      expect(toDisplayName('bulbasaur'), 'Bulbasaur');
    });

    test('converts hyphenated words', () {
      expect(toDisplayName('special-attack'), 'Special Attack');
    });

    test('handles mixed case by uppercasing first letter only', () {
      expect(toDisplayName('mr-mime'), 'Mr Mime');
    });
  });
}
