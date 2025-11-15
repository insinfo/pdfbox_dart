import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_document.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_named.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/documentnavigation/pd_outline_node.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:test/test.dart';

void main() {
  test('existing outline dictionaries materialize into PDOutline wrappers', () {
    final cosDocument = COSDocument();

    final pagesDict = COSDictionary()
      ..setName(COSName.type, 'Pages')
      ..setInt(COSName.count, 1);
    final kids = COSArray();
    pagesDict[COSName.kids] = kids;
    final pagesObject = cosDocument.createObject(pagesDict);

    final pageDict = COSDictionary()
      ..setName(COSName.type, 'Page')
      ..setItem(COSName.parent, pagesObject);
    final pageObject = cosDocument.createObject(pageDict);
    kids.add(pageObject);

    final outlineFirst = COSDictionary()
      ..setString(COSName.title, 'Existing 1')
      ..setItem(
        COSName.dest,
        COSArray()
          ..add(pageObject)
          ..add(COSName.get('Fit')),
      )
      ..setItem(
        COSName.c,
        COSArray()
          ..add(COSFloat(1.0))
          ..add(COSFloat(0.0))
          ..add(COSFloat(0.0)),
      )
      ..setInt(COSName.f, 3);

    final actionDict = COSDictionary()
      ..setName(COSName.s, 'Named')
      ..setName(COSName.n, 'NextDest');
    outlineFirst.setItem(COSName.a, actionDict);

    final structureDict = COSDictionary()..setName(COSName.type, 'StructElem');
    outlineFirst.setItem(COSName.se, structureDict);

    final outlineSecond = COSDictionary()..setString(COSName.title, 'Existing 2');
    outlineFirst.setItem(COSName.next, outlineSecond);
    outlineSecond.setItem(COSName.prev, outlineFirst);
    outlineSecond.setInt(COSName.count, -2);

    final outlinesDict = COSDictionary()
      ..setName(COSName.type, 'Outlines')
      ..setItem(COSName.first, outlineFirst)
      ..setItem(COSName.last, outlineSecond)
      ..setInt(COSName.count, 1);

    final catalogDict = COSDictionary()
      ..setName(COSName.type, 'Catalog')
      ..setItem(COSName.pages, pagesObject)
      ..setItem(COSName.outlines, outlinesDict);
    final catalogObject = cosDocument.createObject(catalogDict);
    cosDocument.trailer[COSName.root] = catalogObject;

    final document = PDDocument.fromCOSDocument(cosDocument);

    final outline = document.documentOutline;
    expect(outline, isNotNull);
    expect(outline, isA<PDOutlineRoot>());
    final first = outline!.firstChild;
    expect(first, isNotNull);
    expect(first!.title, 'Existing 1');
    expect(first.destinationName, isNull);
    expect(first.color, equals(<double>[1.0, 0.0, 0.0]));
    expect(first.isBold, isTrue);
    expect(first.isItalic, isTrue);
    expect(first.structureElement?.getNameAsString(COSName.type), 'StructElem');
    final action = first.action;
    expect(action, isA<PDActionNamed>());
    expect((action as PDActionNamed).namedAction, 'NextDest');

    final pageDest = first.destination?.asPageDestination;
    expect(pageDest, isA<PDPageDestination>());

    final second = first.nextSibling;
    expect(second, isNotNull);
    expect(second!.title, 'Existing 2');
    expect(second.open, isFalse);
    expect(second.openCount, -2);
    expect(second.previousSibling, same(first));
    expect(outline.open, isTrue);
    expect(outline.openCount, 1);
  });
}
