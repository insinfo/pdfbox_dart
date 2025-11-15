import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/pdf_parser.dart';
import 'package:test/test.dart';

void main() {
  group('PDEncryption', () {
    test('wraps encryption dictionary from trailer', () {
      final bytes = _buildEncryptedLikePdf();
      final parser = PDFParser(RandomAccessReadBuffer.fromBytes(bytes));
      final document = parser.parse(lenient: false);
      addTearDown(document.close);

      final encryption = document.encryption;
      expect(encryption, isNotNull);
      expect(encryption!.filter, 'Standard');
      expect(encryption.revision, 2);
      expect(encryption.version, 1);
      expect(encryption.length, 40);
      expect(encryption.encryptMetadata, isTrue);

      final owner = encryption.ownerValue;
      final user = encryption.userValue;
      expect(owner, isNotNull);
      expect(user, isNotNull);
      expect(owner!.string, '01020304');
      expect(user!.string, 'A1B2C3D4');

      // Ensure the encryption dictionary is reachable via the trailer entry.
      final trailerEncrypt = document.cosDocument.trailer.getItem(COSName.encrypt);
      expect(trailerEncrypt, isNotNull);
    });
  });
}

Uint8List _buildEncryptedLikePdf() {
  final buffer = StringBuffer()
    ..writeln('%PDF-1.7');

  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Count 0 /Kids [] >>\nendobj\n',
    '3 0 obj\n'
        '<< /Filter /Standard /V 1 /R 2 /Length 40 /P -4\n'
        '   /EncryptMetadata true /O <3031303230333034> /U <4131423243334434> >>\n'
        'endobj\n',
  ];

  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(buffer.length);
    buffer.write(object);
  }

  final xrefOffset = buffer.length;
  buffer
    ..writeln('xref')
    ..writeln('0 4')
    ..writeln('0000000000 65535 f ');
  for (final offset in offsets) {
    buffer.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
  }
  buffer
    ..writeln('trailer')
    ..writeln('<< /Size 4 /Root 1 0 R /Encrypt 3 0 R >>')
    ..writeln('startxref')
    ..writeln(xrefOffset)
    ..writeln('%%EOF');

  return Uint8List.fromList(utf8.encode(buffer.toString()));
}
