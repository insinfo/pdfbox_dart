import 'package:pdfbox_dart/src/fontbox/ttf/open_type_script.dart';
import 'package:test/test.dart';

void main() {
  group('OpenTypeScript', () {
    test('maps Latin code points to latn script', () {
      final tags = OpenTypeScript.getScriptTags(0x0041);
      expect(tags, orderedEquals(<String>['latn']));
    });

    test('maps Devanagari code points to dev2/deva scripts', () {
      final tags = OpenTypeScript.getScriptTags(0x0915);
      expect(tags, orderedEquals(<String>['dev2', 'deva']));
    });

    test('maps Han ideographs to hani script', () {
      final tags = OpenTypeScript.getScriptTags(0x6F22);
      expect(tags, orderedEquals(<String>['hani']));
    });

    test('returns inherited tag for combining marks', () {
      final tags = OpenTypeScript.getScriptTags(0x0300);
      expect(tags, orderedEquals(<String>[OpenTypeScript.inherited]));
    });

    test('defaults to DFLT for emoji', () {
      final tags = OpenTypeScript.getScriptTags(0x1F600);
      expect(tags, orderedEquals(<String>[OpenTypeScript.tagDefault]));
    });

    test('throws on invalid code points', () {
      expect(() => OpenTypeScript.getScriptTags(-1), throwsArgumentError);
      expect(() => OpenTypeScript.getScriptTags(0x110000), throwsArgumentError);
    });
  });
}
