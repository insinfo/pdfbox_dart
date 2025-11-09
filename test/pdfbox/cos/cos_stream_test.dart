import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/filter_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('COSStream', () {
    test('decode returns raw data when no filters are present', () {
      final stream = COSStream();
      final payload = Uint8List.fromList(<int>[5, 6, 7]);
      stream.data = payload;

      final decoded = stream.decode();
      expect(decoded, equals(payload));
    });

    test('decode applies registered filters', () {
      final stream = COSStream()..setItem(COSName.filter, COSName.flateDecode);
      final raw = Uint8List.fromList('stream data'.codeUnits);
      final encoded = Uint8List.fromList(ZLibEncoder().encode(raw));
      stream.data = encoded;

      final decoded = stream.decode();
      expect(decoded, equals(raw));
    });

    test('decode handles multi-stage filter pipeline', () {
      final stream = COSStream()
        ..setItem(
          COSName.filter,
          COSArray()
            ..add(COSName.ascii85Decode)
            ..add(COSName.flateDecode),
        );
      final pipeline = FilterPipeline(
        parameters: stream,
        filterNames: <COSName>[COSName.ascii85Decode, COSName.flateDecode],
      );
      final raw = Uint8List.fromList('Pipeline'.codeUnits);
      final encoded = pipeline.encode(raw);
      stream.data = encoded;

      final decoded = stream.decode();
      expect(decoded, equals(raw));
    });

    test('exposes encoded and decoded helpers', () {
      final stream = COSStream()..setItem(COSName.filter, COSName.flateDecode);
      final raw = Uint8List.fromList('helpers'.codeUnits);
      final encoded = Uint8List.fromList(ZLibEncoder().encode(raw));
      stream.data = encoded;

      final encodedCopy = stream.encodedBytes();
      expect(encodedCopy, equals(encoded));
      expect(identical(encodedCopy, encoded), isFalse);

      final encodedView = stream.encodedBytes(copy: false);
      expect(encodedView, isNotNull);
      expect(encodedView!.length, equals(encoded.length));

      final decoded = stream.decodeWithResult();
      expect(decoded, isNotNull);
      expect(decoded!.data, equals(raw));
      expect(decoded.results, hasLength(1));
    });
  });
}
