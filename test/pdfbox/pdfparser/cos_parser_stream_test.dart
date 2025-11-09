import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/filter_pipeline.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/cos_parser.dart';
import 'package:test/test.dart';

COSParser _parserFrom(String content) {
  final bytes = Uint8List.fromList(content.codeUnits);
  return COSParser(RandomAccessReadBuffer.fromBytes(bytes));
}

void main() {
  group('COSParser stream handling', () {
    test('returns encoded bytes when decode is disabled', () {
      final stream = COSStream();
      final encoded = Uint8List.fromList(<int>[1, 2, 3, 4]);
      stream.data = encoded;

      final parser = COSParser(RandomAccessReadBuffer.fromBytes(Uint8List(0)));
      final snapshot = stream.encodedBytes(copy: false);

      final parsed = parser.readStream(stream, decode: false);
      expect(parsed.encoded, isNotNull);
      expect(identical(parsed.encoded, snapshot), isTrue);
      expect(parsed.decoded, isNull);
      expect(parsed.decodeResults, isEmpty);
    });

    test('decodes stream when filters are present', () {
      final stream = COSStream()..setItem(COSName.filter, COSName.flateDecode);
      final raw = Uint8List.fromList('dart parser'.codeUnits);
      final encoded = FilterPipeline(
        parameters: stream,
        filterNames: <COSName>[COSName.flateDecode],
      ).encode(raw);
      stream.data = encoded;

      final parser = COSParser(RandomAccessReadBuffer.fromBytes(Uint8List(0)));
      final parsed = parser.readStream(stream);

      expect(parsed.encoded, isNotNull);
      expect(parsed.decoded, equals(raw));
      expect(parsed.decodeResults, hasLength(1));
    });

    test('retains encoded bytes only on request', () {
      final stream = COSStream()
        ..setItem(
          COSName.filter,
          COSName.flateDecode,
        );
      final raw = Uint8List.fromList(List<int>.generate(32, (index) => index));
      final encoded = FilterPipeline(
        parameters: stream,
        filterNames: <COSName>[COSName.flateDecode],
      ).encode(raw);
      stream.data = encoded;

      final parser = COSParser(RandomAccessReadBuffer.fromBytes(Uint8List(0)));
      final parsed = parser.readStream(stream, retainEncodedCopy: false);

      expect(parsed.encoded, isNull);
      expect(parsed.decoded, equals(raw));
    });
  });

  group('COSParser stream parsing', () {
    test('parses stream with explicit length', () {
      final parser = _parserFrom('<< /Length 4 /Subtype /XML >>\nstream\nTest\nendstream\n');
      final stream = parser.parseObject() as COSStream;

      expect(stream.getCOSName(COSName.get('Subtype'))!.name, 'XML');
      expect(stream.getInt(COSName.length), 4);
      expect(stream.data, equals(Uint8List.fromList('Test'.codeUnits)));
    });

    test('parses stream without length using marker scan', () {
      final parser = _parserFrom('<< /Filter /FlateDecode >>\nstream\nabc\nendstream\n');
      final stream = parser.parseObject() as COSStream;

      expect(stream.getCOSName(COSName.filter), equals(COSName.flateDecode));
      expect(stream.data, equals(Uint8List.fromList('abc'.codeUnits)));
    });
  });
}
