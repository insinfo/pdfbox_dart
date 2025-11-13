import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/contentstream/operator/operator.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_stream.dart';
import 'package:test/test.dart';

void main() {
  group('PDContent parsing integration', () {
    test('PDStream parses tokens with PDFStreamParser', () {
      final content = '1 0 0 1 100 200 cm';
      final stream = PDStream.fromBytes(
        Uint8List.fromList(latin1.encode(content)),
      );

      final tokens = stream.parseTokens();
      expect(tokens, isNotEmpty);
      expect(tokens.last, isA<Operator>());
      expect((tokens.last as Operator).name, 'cm');
    });

    test('PDPage parser concatenates multiple streams with delimiters', () {
      final page = PDPage();
      page.setContentStreams(<PDStream>[
        PDStream.fromBytes(Uint8List.fromList(latin1.encode('BT'))),
        PDStream.fromBytes(Uint8List.fromList(latin1.encode('ET'))),
      ]);

      final tokens = page.parseContentStreamTokens();
      expect(tokens, hasLength(2));
      expect(tokens.first, isA<Operator>());
      expect((tokens.first as Operator).name, 'BT');
      expect(tokens.last, isA<Operator>());
      expect((tokens.last as Operator).name, 'ET');
    });

    test('PDPage parser returns empty token list without contents', () {
      final page = PDPage();

      final tokens = page.parseContentStreamTokens();
      expect(tokens, isEmpty);
    });
  });
}
