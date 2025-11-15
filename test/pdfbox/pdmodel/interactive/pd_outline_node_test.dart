import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/documentnavigation/pd_outline_node.dart';
import 'package:test/test.dart';

void main() {
  group('PDOutlineNode hierarchy', () {
    test('addFirst and addLast maintain sibling links', () {
      final root = PDOutlineRoot();
      final first = PDOutlineItem()..title = 'First';
      final second = PDOutlineItem()..title = 'Second';
      final third = PDOutlineItem()..title = 'Third';

      root.addLast(first);
      root.addLast(third);
      root.addFirst(second);

      expect(root.firstChild, same(second));
      expect(root.lastChild, same(third));
      expect(second.parentNode, same(root));
      expect(second.nextSibling, same(first));
      expect(first.previousSibling, same(second));
      expect(third.previousSibling, same(first));
      expect(first.nextSibling, same(third));
    });

    test('remove detaches node and updates parent counts', () {
      final root = PDOutlineRoot();
      final chapter = PDOutlineItem()..title = 'Chapter';
      final section = PDOutlineItem()..title = 'Section';
      final paragraph = PDOutlineItem()..title = 'Paragraph';

      root
        ..addLast(chapter)
        ..addLast(section);
      section.addLast(paragraph);

      expect(root.open, isTrue);
      expect(root.openCount, 3);
      expect(section.open, isTrue);
      expect(section.openCount, 1);

      root.open = true;
      section.open = true;
      expect(root.openCount, 3);
      expect(section.openCount, 1);

      paragraph.remove();
      expect(section.hasChildren, isFalse);
      expect(section.openCount, isNull);
      expect(root.openCount, 2);

      section.remove();
      expect(root.lastChild, same(chapter));
      expect(root.openCount, 1);
      expect(section.parentNode, isNull);
      expect(section.nextSibling, isNull);
      expect(section.previousSibling, isNull);
    });

    test('destinations propagate to explicit destination wrappers', () {
      final item = PDOutlineItem();
      final destArray = COSArray()
        ..add(COSInteger(0))
        ..add(COSName.get('XYZ'))
        ..add(COSInteger(10))
        ..add(COSInteger(20))
        ..add(COSInteger(1));
      final destination = PDPageDestination.fromArray(destArray);
      expect(destination, isNotNull);

      item.destination = destination;
      final resolved = item.destination;
      expect(resolved, isA<PDPageDestination>());
      expect((resolved as PDPageDestination).pageNumber, 0);

      item.destinationName = 'NamedDest';
      expect(item.destination, isA<PDNamedDestination>());
      expect(item.destinationName, 'NamedDest');
      item.destinationName = null;
      expect(item.destinationName, isNull);
      expect(item.destination, isNull);

      item.destination = destination;
      expect(item.destination, isA<PDPageDestination>());
    });

    test('color, style and structure element round trip', () {
      final item = PDOutlineItem();
      item.color = <double>[1.0, 0.5, 0.25];
      item.isBold = true;
      item.isItalic = false;

      final structure = COSDictionary()..setName(COSName.type, 'StructElem');
      item.structureElement = structure;

      expect(item.color, equals(<double>[1.0, 0.5, 0.25]));
      expect(item.isBold, isTrue);
      expect(item.isItalic, isFalse);
      expect(item.structureElement, same(structure));

      item.isItalic = true;
      expect(item.isItalic, isTrue);

      item.color = null;
      expect(item.color, isNull);

      final dict = COSDictionary()
        ..setString(COSName.title, 'Styled')
        ..setItem(
          COSName.c,
          COSArray()
            ..add(COSFloat(0.0))
            ..add(COSFloat(0.0))
            ..add(COSFloat(1.0)),
        )
        ..setInt(COSName.f, 3);
      final imported = PDOutlineItem(dictionary: dict);
      expect(imported.color, equals(<double>[0.0, 0.0, 1.0]));
      expect(imported.isBold, isTrue);
      expect(imported.isItalic, isTrue);
    });
  });
}
