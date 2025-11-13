import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';

void main() {
  group('PDDocument incremental save', () {
    final signedPdfPath = 'resources/doc_assinado_pmro.pdf';

    test('saveIncremental preserves signed document bytes without changes',
        () async {
      final file = File(signedPdfPath);
      expect(await file.exists(), isTrue,
          reason: 'Signed PDF not found at $signedPdfPath');

      final originalBytes = await file.readAsBytes();

      final document = PDDocument.loadFile(file.path, lenient: true);
      addTearDown(() => document.close());

      final original = RandomAccessReadBufferedFile(file.path);
      addTearDown(() => original.close());

      final buffer = RandomAccessReadWriteBuffer();
      addTearDown(() => buffer.close());

      document.saveIncremental(original, buffer);

      buffer.seek(0);
      final savedBytes = Uint8List(buffer.length);
      buffer.readFully(savedBytes);

      expect(savedBytes, orderedEquals(originalBytes));
    });

    test('saveIncremental appends changes and invalidates signature if modified',
        () async {
      final file = File(signedPdfPath);
      expect(await file.exists(), isTrue,
          reason: 'Signed PDF not found at $signedPdfPath');

      final original = RandomAccessReadBufferedFile(file.path);
      addTearDown(() => original.close());

      final document = PDDocument.loadFile(file.path, lenient: true);
      addTearDown(() => document.close());

      final originalBytes = await file.readAsBytes();

      // Mutate metadata to force an incremental update section.
      final info = document.documentInformation;
      final previousTitle = info.title;
      info.title = 'Incremental Update Test';

      final buffer = RandomAccessReadWriteBuffer();
      addTearDown(() => buffer.close());

      document.saveIncremental(original, buffer);

      buffer.seek(0);
      final savedBytes = Uint8List(buffer.length);
      buffer.readFully(savedBytes);

      expect(savedBytes.length, greaterThan(originalBytes.length));
      expect(savedBytes.sublist(0, originalBytes.length), orderedEquals(originalBytes));

      final appendedSegment = savedBytes.sublist(originalBytes.length);
      final appendedText = String.fromCharCodes(appendedSegment);
      expect(appendedText, contains('/Title (Incremental Update Test)'));

      // Restore metadata to avoid cascading changes for subsequent tests.
      info.title = previousTitle;
    });
  });
}
