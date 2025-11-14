import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfwriter/compress/compress_parameters.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfwriter/pdf_save_options.dart';

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

    test('saveIncremental maintains xref stream structure', () async {
      final baseDocument = PDDocument();
      addTearDown(() => baseDocument.close());

      baseDocument.addPage(PDPage());
      baseDocument.documentInformation.author = 'Initial Author';

      final originalBytes = baseDocument.saveToBytes(
        options: const PDFSaveOptions(
          compressStreams: true,
          objectStreamCompression: CompressParameters(),
        ),
      );

      final document = PDDocument.loadFromBytes(originalBytes);
      addTearDown(() => document.close());

      document.documentInformation.author = 'Updated Author';

      final original = RandomAccessReadBuffer.fromBytes(
        Uint8List.fromList(originalBytes),
      );
      addTearDown(() => original.close());

      final buffer = RandomAccessReadWriteBuffer();
      addTearDown(() => buffer.close());

      document.saveIncremental(original, buffer);

      buffer.seek(0);
      final savedBytes = Uint8List(buffer.length);
      buffer.readFully(savedBytes);

      expect(savedBytes.length, greaterThan(originalBytes.length));

      final appended = savedBytes.sublist(originalBytes.length);
      final appendedText = latin1.decode(appended, allowInvalid: true);

      expect(appendedText.contains('/Type /XRef'), isTrue);
      expect(appendedText.contains('\nxref\n'), isFalse);

      final reloaded = PDDocument.loadFromBytes(savedBytes);
      addTearDown(() => reloaded.close());
      expect(reloaded.cosDocument.isXRefStream, isTrue);
      expect(reloaded.documentInformation.author, 'Updated Author');
    });

    test('saveIncremental emits hybrid xref table and stream when required', () async {
      final baseDocument = PDDocument();
      addTearDown(() => baseDocument.close());

      baseDocument.addPage(PDPage());
      baseDocument.documentInformation.title = 'Hybrid Base';

      final originalBytes = baseDocument.saveToBytes(
        options: const PDFSaveOptions(
          compressStreams: true,
          objectStreamCompression: CompressParameters(),
        ),
      );

      final document = PDDocument.loadFromBytes(originalBytes);
      addTearDown(() => document.close());

      document.cosDocument.markHybridXRef();
      final startXref = document.cosDocument.startXref;
      if (startXref != null) {
        document.cosDocument.trailer.setInt(COSName.xrefStm, startXref);
      }

      expect(document.cosDocument.hasHybridXRef, isTrue,
          reason: 'Hybrid flag not set before incremental save');
      expect(document.cosDocument.isXRefStream, isTrue,
          reason: 'Hybrid scenario requires base document to use xref stream');

      document.documentInformation.title = 'Hybrid Update';

      final original = RandomAccessReadBuffer.fromBytes(
        Uint8List.fromList(originalBytes),
      );
      addTearDown(() => original.close());

      final buffer = RandomAccessReadWriteBuffer();
      addTearDown(() => buffer.close());

      document.saveIncremental(original, buffer);

      buffer.seek(0);
      final savedBytes = Uint8List(buffer.length);
      buffer.readFully(savedBytes);

      expect(savedBytes.length, greaterThan(originalBytes.length));

      final appended = savedBytes.sublist(originalBytes.length);
      final appendedText = latin1.decode(appended, allowInvalid: true);

      expect(appendedText.contains('\nxref\n'), isTrue,
          reason: 'Hybrid incremental update must append a classic xref table');
      expect(appendedText.contains('/Type /XRef'), isTrue,
          reason: 'Hybrid incremental update must serialize an xref stream object');
      expect(appendedText.contains('/XRefStm'), isTrue,
          reason: 'Trailer must reference the appended xref stream');

      final reloaded = PDDocument.loadFromBytes(savedBytes);
      addTearDown(() => reloaded.close());
      expect(reloaded.cosDocument.hasHybridXRef, isTrue);
      expect(reloaded.cosDocument.isXRefStream, isFalse);
      expect(reloaded.documentInformation.title, 'Hybrid Update');
    });
  });
}
