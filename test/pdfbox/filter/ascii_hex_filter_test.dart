import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/ascii_hex_filter.dart';
import 'package:test/test.dart';

void main() {
  group('ASCIIHexFilter', () {
    test('decodes simple hex payload', () {
      final filter = ASCIIHexFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCIIHexDecode'));
      final encoded = Uint8List.fromList('48656C6C6F>'.codeUnits);

      final result = filter.decode(encoded, parameters, 0);
      expect(result.data, equals(Uint8List.fromList('Hello'.codeUnits)));
    });

    test('decodes odd nibble by padding low digit with zero', () {
      final filter = ASCIIHexFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCIIHexDecode'));
      final encoded = Uint8List.fromList('61 62 63 64 65 6 >'.codeUnits);

      final result = filter.decode(encoded, parameters, 0);
      expect(result.data, equals(<int>[0x61, 0x62, 0x63, 0x64, 0x65, 0x60]));
    });

    test('encodes bytes with uppercase hex digits', () {
      final filter = ASCIIHexFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCIIHexDecode'));
      final data = Uint8List.fromList('Hello'.codeUnits);

  final encoded = filter.encode(data, parameters, 0);
      expect(String.fromCharCodes(encoded), equals('48656C6C6F>'));
    });

    test('throws on invalid character', () {
      final filter = ASCIIHexFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCIIHexDecode'));
      final encoded = Uint8List.fromList('G>'.codeUnits);

      expect(
        () => filter.decode(encoded, parameters, 0),
        throwsA(isA<IOException>()),
      );
    });
  });
}
