import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/ttf/font_headers.dart';
import 'package:test/test.dart';

void main() {
  group('FontHeaders', () {
    test('captures metadata from multiple sources', () {
      final headers = FontHeaders()
        ..setError('missing table')
        ..setName('MyFont-Regular')
        ..setHeaderMacStyle(0x20)
        ..setOs2Windows(_DummyOs2())
        ..setFontFamily('MyFont', 'Regular')
        ..setNonOtfGcid142(Uint8List.fromList(<int>[1, 2, 3]))
        ..setIsOtfAndPostScript(true)
        ..setOtfRos('Adobe', 'Identity', 1);

      expect(headers.error, 'missing table');
      expect(headers.name, 'MyFont-Regular');
      expect(headers.headerMacStyle, 0x20);
      expect(headers.os2Windows, isA<_DummyOs2>());
      expect(headers.fontFamily, 'MyFont');
      expect(headers.fontSubFamily, 'Regular');
      expect(headers.isOpenTypePostScript, isTrue);
      expect(headers.otfRegistry, 'Adobe');
      expect(headers.otfOrdering, 'Identity');
      expect(headers.otfSupplement, 1);
      expect(headers.nonOtfTableGcid142, orderedEquals(<int>[1, 2, 3]));
    });
  });
}

class _DummyOs2 {}
