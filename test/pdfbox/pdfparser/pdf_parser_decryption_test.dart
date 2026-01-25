import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/access_permission.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/invalid_password_exception.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_decryption_material.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_protection_policy.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/encryption/standard_security_handler.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/pdf_parser.dart';
import 'package:test/test.dart';

void main() {
  group('PDFParser decryption', () {
    test('parses encrypted info dictionary with password', () {
      const ownerPassword = 'owner-pass';
      const userPassword = 'user-pass';
      const title = 'Secret Title';

      final bytes = _buildEncryptedPdf(
        ownerPassword: ownerPassword,
        userPassword: userPassword,
        title: title,
      );

      final parser = PDFParser(RandomAccessReadBuffer.fromBytes(bytes));
      final document = parser.parse(
        lenient: false,
        password: userPassword,
      );
      addTearDown(document.close);

      expect(document.documentInformation.title, equals(title));
      expect(document.currentAccessPermission.isReadOnly, isTrue);
    });

    test('throws on invalid password', () {
      const ownerPassword = 'owner-pass';
      const userPassword = 'user-pass';

      final bytes = _buildEncryptedPdf(
        ownerPassword: ownerPassword,
        userPassword: userPassword,
        title: 'Secret Title',
      );

      final parser = PDFParser(RandomAccessReadBuffer.fromBytes(bytes));
      expect(
        () => parser.parse(lenient: false, password: 'wrong'),
        throwsA(isA<InvalidPasswordException>()),
      );
    });
  });

  group('PDDocument load helpers', () {
    test('loadFromBytes supports password', () {
      const ownerPassword = 'owner-pass';
      const userPassword = 'user-pass';
      const title = 'Secret Title';

      final bytes = _buildEncryptedPdf(
        ownerPassword: ownerPassword,
        userPassword: userPassword,
        title: title,
      );

      final document = PDDocument.loadFromBytes(
        bytes,
        lenient: false,
        password: userPassword,
      );
      addTearDown(document.close);

      expect(document.documentInformation.title, equals(title));
      expect(document.currentAccessPermission.isReadOnly, isTrue);
    });

    test('loadFromBytes supports decryption material', () {
      const ownerPassword = 'owner-pass';
      const userPassword = 'user-pass';
      const title = 'Secret Title';

      final bytes = _buildEncryptedPdf(
        ownerPassword: ownerPassword,
        userPassword: userPassword,
        title: title,
      );

      final material = StandardDecryptionMaterial(userPassword);
      final document = PDDocument.loadFromBytes(
        bytes,
        lenient: false,
        decryptionMaterial: material,
      );
      addTearDown(document.close);

      expect(document.documentInformation.title, equals(title));
      expect(document.currentAccessPermission.isReadOnly, isTrue);
    });

    test('loadFromBytes throws on invalid password', () {
      const ownerPassword = 'owner-pass';
      const userPassword = 'user-pass';

      final bytes = _buildEncryptedPdf(
        ownerPassword: ownerPassword,
        userPassword: userPassword,
        title: 'Secret Title',
      );

      expect(
        () => PDDocument.loadFromBytes(
          bytes,
          lenient: false,
          password: 'wrong',
        ),
        throwsA(isA<InvalidPasswordException>()),
      );
    });
  });
}

Uint8List _buildEncryptedPdf({
  required String ownerPassword,
  required String userPassword,
  required String title,
}) {
  final document = PDDocument();
  document.addPage(PDPage());

  final policy = StandardProtectionPolicy(
    ownerPassword,
    userPassword,
    AccessPermission(),
  )..setEncryptionKeyLength(40);
  final handler = StandardSecurityHandler(policy);
  handler.prepareDocumentForEncryption(document);

  final encryption = document.encryption;
  if (encryption == null) {
    throw StateError('Encryption dictionary not available');
  }

  final encryptedTitle =
      handler.encryptString(COSString(title), 5, 0) as COSString;
  final titleHex = _toHex(encryptedTitle.bytes);

  final ownerHex = _toHex(encryption.ownerValue?.bytes ?? Uint8List(0));
  final userHex = _toHex(encryption.userValue?.bytes ?? Uint8List(0));
  final idArray = document.cosDocument.trailer.getCOSArray(COSName.id);
  final idHexes = _idHexes(idArray);

    final encryptDictionary = '<< /Filter /Standard '
      '/V ${encryption.version} '
      '/R ${encryption.revision} '
      '/Length ${encryption.length} '
      '/P ${encryption.permissions} '
      '/EncryptMetadata ${encryption.encryptMetadata} '
      '/O <$ownerHex> '
      '/U <$userHex> >>';

    final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] '
        '/Contents 4 0 R >>\nendobj\n',
    '4 0 obj\n<< /Length 0 >>\nstream\n\nendstream\nendobj\n',
    '5 0 obj\n<< /Title <$titleHex> >>\nendobj\n',
  ];

  final buffer = StringBuffer()..writeln('%PDF-1.4');
  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(buffer.length);
    buffer.write(object);
  }

  final xrefOffset = buffer.length;
  buffer
    ..writeln('xref')
    ..writeln('0 ${objects.length + 1}')
    ..writeln('0000000000 65535 f ');
  for (final offset in offsets) {
    buffer.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
  }

  buffer
    ..writeln('trailer')
    ..writeln('<< /Size ${objects.length + 1} /Root 1 0 R /Info 5 0 R '
        '/Encrypt $encryptDictionary /ID [${idHexes.join(' ')}] >>')
    ..writeln('startxref')
    ..writeln(xrefOffset)
    ..writeln('%%EOF');

  document.close();
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}

String _toHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final value in bytes) {
    buffer.write(value.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

List<String> _idHexes(dynamic idArray) {
  if (idArray == null || idArray.length < 2) {
    return <String>['<00>', '<00>'];
  }
  final first = idArray.getObject(0);
  final second = idArray.getObject(1);
  final firstHex = first is COSString ? _toHex(first.bytes) : '00';
  final secondHex = second is COSString ? _toHex(second.bytes) : '00';
  return <String>['<$firstHex>', '<$secondHex>'];
}

