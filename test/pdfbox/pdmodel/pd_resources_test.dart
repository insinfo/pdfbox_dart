import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:test/test.dart';

void main() {
  group('PDResources', () {
    test('registerStandard14Font creates font dictionary', () {
      final resources = PDResources();
      final fontName = COSName.get('F1');

      final fontDictionary = resources.registerStandard14Font(fontName, 'Helvetica');

      expect(resources.hasFontResources, isTrue);
      expect(resources.getFont(fontName), isNotNull);
      expect(resources.fontNames, contains(fontName));
      expect(fontDictionary.getNameAsString(COSName.type), 'Font');
      expect(fontDictionary.getNameAsString(COSName.subtype), 'Type1');
      expect(fontDictionary.getNameAsString(COSName.baseFont), 'Helvetica');
      expect(fontDictionary.getNameAsString(COSName.encoding), 'WinAnsiEncoding');
    });

    test('removeFont clears dictionary when empty', () {
      final resources = PDResources();
      final fontName = COSName.get('F2');
      resources.registerStandard14Font(fontName, 'Times-Roman');
      resources.removeFont(fontName);

      expect(resources.hasFontResources, isFalse);
      expect(resources.getFont(fontName), isNull);
      expect(resources.fontNames, isEmpty);
    });

    test('setFont stores custom font dictionary', () {
      final resources = PDResources();
      final fontName = COSName.get('Custom');
      final dictionary = COSDictionary()
        ..setName(COSName.type, 'Font')
        ..setName(COSName.subtype, 'Type0')
        ..setName(COSName.baseFont, 'Custom-Font');

      resources.setFont(fontName, dictionary);

      final stored = resources.getFont(fontName);
      expect(stored, isNotNull);
      expect(stored!.getNameAsString(COSName.subtype), 'Type0');
      expect(resources.fontNames, contains(fontName));
    });
  });
}
