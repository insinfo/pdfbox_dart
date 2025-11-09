import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/ascii85_filter.dart';
import 'package:test/test.dart';

void main() {
  group('ASCII85Filter', () {
    test('decodes canonical payload', () {
      final filter = ASCII85Filter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCII85Decode'));
      final encoded = Uint8List.fromList('87cURDZ~>'.codeUnits);

      final result = filter.decode(encoded, parameters, 0);
      expect(result.data, equals(Uint8List.fromList('Hello'.codeUnits)));
    });

    test('decodes zero run-length shortcut', () {
      final filter = ASCII85Filter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCII85Decode'));
      final encoded = Uint8List.fromList('z~>'.codeUnits);

      final result = filter.decode(encoded, parameters, 0);
      expect(result.data, equals(<int>[0, 0, 0, 0]));
    });

    test('encodes bytes with end-of-data marker', () {
      final filter = ASCII85Filter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCII85Decode'));
      final data = Uint8List.fromList('Hello'.codeUnits);

  final encoded = filter.encode(data, parameters, 0);
      expect(String.fromCharCodes(encoded), equals('87cURDZ~>'));
    });

    test('decodes ignoring whitespace and trailing data', () {
      final filter = ASCII85Filter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCII85Decode'));
      final encoded = Uint8List.fromList(' 87cU RDZ~>\n>'.codeUnits);

      final result = filter.decode(encoded, parameters, 0);
      expect(result.data, equals(Uint8List.fromList('Hello'.codeUnits)));
    });

    test('throws when z appears mid-group', () {
      final filter = ASCII85Filter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCII85Decode'));
      final encoded = Uint8List.fromList('!z!!!~>'.codeUnits);

      expect(
        () => filter.decode(encoded, parameters, 0),
        throwsA(isA<IOException>()),
      );
    });

    test('encodes empty input as terminator sequence', () {
      final filter = ASCII85Filter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName('ASCII85Decode'));

  final encoded = filter.encode(Uint8List(0), parameters, 0);
      expect(String.fromCharCodes(encoded), equals('~>'));
    });
  });
}
