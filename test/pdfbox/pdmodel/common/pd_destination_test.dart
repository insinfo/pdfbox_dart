import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:test/test.dart';

void main() {
  group('PDDestination', () {
    test('creates named destination from COSName', () {
      final dest = PDDestination.fromCOS(COSName('Chapter1'));
      expect(dest, isA<PDNamedDestination>());
      expect((dest as PDNamedDestination).name, 'Chapter1');
    });

    test('creates named destination from COSString', () {
      final dest = PDDestination.fromCOS(COSString('Intro'));
      expect(dest, isA<PDNamedDestination>());
      expect((dest as PDNamedDestination).name, 'Intro');
    });

    test('creates page XYZ destination from COSArray', () {
      final array = COSArray()
        ..add(COSInteger(0))
        ..add(COSName.get('XYZ'))
        ..add(COSFloat(10))
        ..add(COSFloat(20))
        ..add(COSFloat(0));
      final dest = PDDestination.fromCOS(array);
      expect(dest, isA<PDPageXYZDestination>());
      final pageDest = dest as PDPageXYZDestination;
      expect(pageDest.array, same(array));
      expect(pageDest.pageNumber, 0);
      expect(pageDest.left, 10);
      expect(pageDest.top, 20);
      expect(pageDest.zoom, 0);
    });

    test('creates page fit destinations from COSArray tokens', () {
      final fitArray = COSArray()
        ..add(COSInteger(1))
        ..add(COSName.get('Fit'));
      final fit = PDDestination.fromCOS(fitArray);
      expect(fit, isA<PDPageFitDestination>());
      expect((fit as PDPageFitDestination).fitType, 'Fit');

      final fitHArray = COSArray()
        ..add(COSInteger(2))
        ..add(COSName.get('FitH'))
        ..add(COSFloat(42));
      final fitH = PDDestination.fromCOS(fitHArray);
      expect(fitH, isA<PDPageFitHorizontalDestination>());
      expect((fitH as PDPageFitHorizontalDestination).top, 42);

      final fitVArray = COSArray()
        ..add(COSInteger(3))
        ..add(COSName.get('FitV'))
        ..add(COSFloat(77));
      final fitV = PDDestination.fromCOS(fitVArray);
      expect(fitV, isA<PDPageFitVerticalDestination>());
      expect((fitV as PDPageFitVerticalDestination).left, 77);

      final fitRArray = COSArray()
        ..add(COSInteger(4))
        ..add(COSName.get('FitR'))
        ..add(COSFloat(10))
        ..add(COSFloat(20))
        ..add(COSFloat(110))
        ..add(COSFloat(120));
      final fitR = PDDestination.fromCOS(fitRArray);
      expect(fitR, isA<PDPageFitRectangleDestination>());
      final fitRect = fitR as PDPageFitRectangleDestination;
      expect(fitRect.left, 10);
      expect(fitRect.bottom, 20);
      expect(fitRect.right, 110);
      expect(fitRect.top, 120);
    });

    test('falls back to explicit destination for unknown type', () {
      final array = COSArray()
        ..add(COSInteger(5))
        ..add(COSName.get('Custom'));
      final dest = PDDestination.fromCOS(array);
      expect(dest, isA<PDExplicitDestination>());
      expect((dest as PDExplicitDestination).length, 2);
    });

    test('creates explicit destination from dictionary with /D array', () {
      final array = COSArray()..add(COSInteger(2));
      final dict = COSDictionary()..setItem(COSName.d, array);
      final dest = PDDestination.fromCOS(dict);
      expect(dest, isA<PDPageDestination>());
      expect((dest as PDPageDestination).array, same(array));
    });

    test('falls back to nested destination inside dictionary', () {
      final dict = COSDictionary()..setItem(COSName.d, COSString('NamedDest'));
      final dest = PDDestination.fromCOS(dict);
      expect(dest, isA<PDNamedDestination>());
      expect((dest as PDNamedDestination).name, 'NamedDest');
    });
  });
}
