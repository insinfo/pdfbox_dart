import 'package:pdfbox_dart/src/fontbox/ttf/gsub/compound_character_tokenizer.dart';
import 'package:test/test.dart';

void main() {
  group('CompoundCharacterTokenizer', () {
    test('splits compound glyph strings into meaningful tokens', () {
      final tokenizer = CompoundCharacterTokenizer(<String>{'_1_2_', '_3_4_'});
      final tokens = tokenizer.tokenize('_1_2_5_3_4_');

      expect(tokens, <String>['_1_2_', '_5', '_3_4_']);
    });

    test('validates compound tokens', () {
      expect(() => CompoundCharacterTokenizer(<String>{}), throwsArgumentError);
      expect(() => CompoundCharacterTokenizer(<String>{'1_2'}),
          throwsArgumentError);
    });
  });
}
