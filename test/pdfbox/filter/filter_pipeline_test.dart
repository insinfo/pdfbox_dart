import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/filter_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('FilterPipeline', () {
    test('returns input when filter list is empty', () {
      final parameters = COSDictionary();
      final pipeline = FilterPipeline(
        parameters: parameters,
        filterNames: const <COSName>[],
      );
      final data = Uint8List.fromList(<int>[1, 2, 3]);

      final result = pipeline.decode(data);
      expect(result.data, equals(data));
    });

    test('encodes and decodes composite filter chain', () {
      final pipeline = FilterPipeline(
        parameters: COSDictionary(),
        filterNames: <COSName>[COSName.ascii85Decode, COSName.flateDecode],
      );

      final raw = Uint8List.fromList('Dart PDFBox'.codeUnits);
      final encoded = pipeline.encode(raw);
      final manualAscii = Uint8List.fromList('~>'.codeUnits);
      expect(encoded, isNot(equals(raw)));
      expect(encoded, isNotEmpty);
      expect(encoded.sublist(encoded.length - manualAscii.length), equals(manualAscii));

      final decoded = pipeline.decode(encoded).data;
      expect(decoded, equals(raw));
    });
  });
}
