import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/flate_filter.dart';
import 'package:test/test.dart';

void main() {
  group('FlateFilter', () {
    test('round-trips raw bytes', () {
      final filter = FlateFilter();
      final data = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final encoded = Uint8List.fromList(ZLibEncoder().encode(data));
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('FlateDecode'));

      final result = filter.decode(encoded, parameters, 0);
      expect(result.data, equals(data));

  final reencoded = filter.encode(result.data, parameters, 0);
  final decodedAgain = filter.decode(reencoded, parameters, 0).data;
      expect(decodedAgain, equals(data));
    });

    test('applies PNG Up predictor', () {
      final filter = FlateFilter();
      final decodeParams = COSDictionary()
        ..setInt(COSName.predictor, 12)
        ..setInt(COSName.colors, 1)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setInt(COSName.columns, 3);

      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('FlateDecode'))
        ..setItem(COSName.decodeParms, decodeParams);

      final row1 = <int>[10, 20, 30];
      final deltasRow2 = <int>[5, 5, 5];
      final predicted = Uint8List.fromList(
        <int>[2, ...row1, 2, ...deltasRow2],
      );
      final encoded = Uint8List.fromList(ZLibEncoder().encode(predicted));

      final result = filter.decode(encoded, parameters, 0);
  expect(result.data, equals(<int>[10, 20, 30, 15, 25, 35]));
    });

    test('removes PNG per-row predictor byte', () {
      final filter = FlateFilter();
      final decodeParams = COSDictionary()
        ..setInt(COSName.predictor, 15)
        ..setInt(COSName.colors, 1)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setInt(COSName.columns, 2);

      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('FlateDecode'))
        ..setItem(COSName.decodeParms, decodeParams);

      final input = Uint8List.fromList(<int>[0, 5, 7, 0, 1, 2]);
      final encoded = Uint8List.fromList(ZLibEncoder().encode(input));

      final result = filter.decode(encoded, parameters, 0);
  expect(result.data, equals(<int>[5, 7, 1, 2]));
    });
  });
}
