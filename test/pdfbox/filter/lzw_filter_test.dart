import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/lzw_filter.dart';
import 'package:test/test.dart';

void main() {
  group('LZWFilter', () {
    test('round-trips raw bytes', () {
      final filter = LZWFilter();
      final data = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('LZWDecode'));

  final encoded = filter.encode(data, parameters, 0);
      final decoded = filter.decode(encoded, parameters, 0).data;
      expect(decoded, equals(data));
    });

    test('applies PNG Up predictor when decoding', () {
      final filter = LZWFilter();
      final decodeParams = COSDictionary()
        ..setInt(COSName.predictor, 12)
        ..setInt(COSName.colors, 1)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setInt(COSName.columns, 3);
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('LZWDecode'))
        ..setItem(COSName.decodeParms, decodeParams);

      final row1 = <int>[10, 20, 30];
      final deltasRow2 = <int>[5, 5, 5];
      final predicted = Uint8List.fromList(<int>[2, ...row1, 2, ...deltasRow2]);

  final encoded = filter.encode(predicted, parameters, 0);
      final decoded = filter.decode(encoded, parameters, 0).data;
      expect(decoded, equals(<int>[10, 20, 30, 15, 25, 35]));
    });

    test('honors earlyChange = 0', () {
      final filter = LZWFilter();
      final decodeParams = COSDictionary()
        ..setInt(COSName.earlyChange, 0);
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('LZWDecode'))
        ..setItem(COSName.decodeParms, decodeParams);

      final data = Uint8List.fromList(
        List<int>.generate(64, (index) => (index * 7) & 0xFF),
      );
  final encoded = filter.encode(data, parameters, 0);
      final decoded = filter.decode(encoded, parameters, 0).data;
      expect(decoded, equals(data));
    });

  });
}
