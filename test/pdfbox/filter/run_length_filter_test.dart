import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/run_length_filter.dart';
import 'package:test/test.dart';

void main() {
  group('RunLengthFilter', () {
    test('decodes literal and repeated segments', () {
      final filter = RunLengthFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName.runLengthDecode);
      final encoded =
          Uint8List.fromList(<int>[2, 0x41, 0x42, 0x43, 254, 0x20, 128]);

      final result = filter.decode(encoded, parameters, 0);
      expect(result.data, equals(Uint8List.fromList('ABC   '.codeUnits)));
    });

    test('round-trips arbitrary data', () {
      final filter = RunLengthFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName.runLengthDecode);
      final data =
          Uint8List.fromList(List<int>.generate(256, (index) => index % 97));

      final encoded = filter.encode(data, parameters, 0);
      final decoded = filter.decode(encoded, parameters, 0).data;
      expect(decoded, equals(data));
    });
  });
}
