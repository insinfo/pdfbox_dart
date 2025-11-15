import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/pdf_parser.dart';
import 'package:test/test.dart';

void main() {
  group('COSParser lenient recovery', () {
    test('falls back to brute-force parsing when startxref is corrupt', () {
      final pdf = _buildSimplePdfWithBadStartXref();

      final lenientParser =
          PDFParser(RandomAccessReadBuffer.fromBytes(pdf));
      final document = lenientParser.parse(lenient: true);
      addTearDown(document.close);

      expect(document.numberOfPages, 0);
      expect(document.cosDocument.xrefTable, isNotEmpty);
      expect(document.cosDocument.startXref, 0);

      expect(
        () =>
            PDFParser(RandomAccessReadBuffer.fromBytes(pdf)).parse(lenient: false),
        throwsA(isA<IOException>()),
      );
    });
  });
}

Uint8List _buildSimplePdfWithBadStartXref() {
  final buffer = StringBuffer()
    ..writeln('%PDF-1.4');

  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Count 0 /Kids [] >>\nendobj\n',
  ];

  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(buffer.length);
    buffer.write(object);
  }

  final xrefOffset = buffer.length;
  buffer
    ..writeln('xref')
    ..writeln('0 3')
    ..writeln('0000000000 65535 f ');
  for (final offset in offsets) {
    final bogusOffset = offset + 5000;
    buffer.writeln('${bogusOffset.toString().padLeft(10, '0')} 00000 n ');
  }
  buffer
    ..writeln('trailer')
    ..writeln('<< /Size 3 /Root 1 0 R >>')
    ..writeln('startxref')
    ..writeln(xrefOffset)
    ..writeln('%%EOF');

  return Uint8List.fromList(utf8.encode(buffer.toString()));
}
