import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/true_type_embedder.dart';

void main() {
  test('TrueTypeEmbedder subset includes cmap/post and is reparseable', () {
    final ttfPath = 'resources/ttf/LiberationSans-Regular.ttf';
    final bytes = File(ttfPath).readAsBytesSync();

    final original = TtfParser().parse(
      RandomAccessReadBuffer.fromBytes(Uint8List.fromList(bytes)),
    );

    try {
      final embedder = TrueTypeEmbedder(original, embedSubset: true);
      embedder.addToSubset('H'.codeUnitAt(0));
      embedder.addToSubset('I'.codeUnitAt(0));

      final result = embedder.subset();

      final subsetFont = TtfParser(isEmbedded: false).parse(
        RandomAccessReadBuffer.fromBytes(result.fontData),
      );
      try {
        expect(subsetFont.getCmapTable(), isNotNull);
        expect(subsetFont.getUnicodeCmapLookup(), isNotNull);
        expect(subsetFont.getPostScriptTable(), isNotNull);
      } finally {
        subsetFont.close();
      }
    } finally {
      original.close();
    }
  });
}

