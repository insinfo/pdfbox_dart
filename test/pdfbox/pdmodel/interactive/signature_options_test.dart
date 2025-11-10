import 'dart:async';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/signature_options.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:test/test.dart';

Uint8List _createSamplePdf() {
  final document = PDDocument();
  document.addPage(PDPage());
  final bytes = document.saveToBytes();
  document.close();
  return bytes;
}

void main() {
  group('SignatureOptions', () {
    test('page setter enforces non-negative values', () {
      final options = SignatureOptions();
      expect(options.page, equals(0));
      options.page = 2;
      expect(options.page, equals(2));
      expect(() => options.page = -1, throwsArgumentError);
    });

    test('preferred signature size ignores non-positive values', () {
      final options = SignatureOptions();
      expect(options.preferredSignatureSize, equals(0));
      options.setPreferredSignatureSize(-10);
      expect(options.preferredSignatureSize, equals(0));
      options.setPreferredSignatureSize(2048);
      expect(options.preferredSignatureSize, equals(2048));
      options.setPreferredSignatureSize(0);
      expect(options.preferredSignatureSize, equals(2048));
    });

    test('visual signature loads from bytes', () {
      final bytes = _createSamplePdf();
      final options = SignatureOptions();

      options.setVisualSignatureFromBytes(bytes);

      final visualDoc = options.visualSignature;
      expect(visualDoc, isNotNull);
      expect(visualDoc!.isClosed, isFalse);
      expect(
        visualDoc.trailer.getDictionaryObject(COSName.root),
        isNotNull,
      );

      options.close();
      expect(visualDoc.isClosed, isTrue);
      expect(options.visualSignature, isNull);
    });

    test('visual signature loads from stream', () async {
      final bytes = _createSamplePdf();
      final options = SignatureOptions();

      final stream = Stream<List<int>>.fromIterable(<List<int>>[bytes]);
      await options.setVisualSignatureFromStream(stream);

      expect(options.visualSignature, isNotNull);

      options.close();
    });
  });
}