import 'package:flutter_test/flutter_test.dart';

import 'package:coachnutri/features/recipes/utils.dart';

void main() {
  group('toKey', () {
    test('lowercases and strips spaces/punctuations', () {
      expect(toKey('  Pâte à Pizza!  '), 'pateapizza');
    });

    test('removes french diacritics', () {
      expect(toKey('Crème fraîche'), 'cremefraiche');
      expect(toKey('Œuf / œuf'), 'oeufoeuf');
    });
  });
}
