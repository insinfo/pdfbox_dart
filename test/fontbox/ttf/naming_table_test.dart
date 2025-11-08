import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/name_record.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/naming_table.dart';

void main() {
  group('NamingTable', () {
    test('reads format 1 records and resolves language tag lookups', () {
      final storageOffset = 0x0018;
      final bytes = Uint8List.fromList(<int>[
        0x00, 0x01, // format 1
        0x00, 0x01, // numberOfNameRecords
        (storageOffset >> 8) & 0xFF,
        storageOffset & 0xFF, // storageOffset
        0x00, 0x03, // platformId: Windows
        0x00, 0x01, // platformEncodingId: Unicode BMP
        0x80, 0x00, // languageId: tag index 0 (0x8000)
        0x00, 0x01, // nameId: Font family name
        0x00, 0x08, // stringLength: 8 bytes (UTF-16 "Test")
        0x00, 0x00, // stringOffset: 0
        0x00, 0x01, // langTagCount: 1
        0x00, 0x0A, // langTag length (10 bytes -> 5 UTF-16 chars)
        0x00, 0x08, // langTag offset (after "Test")
        // UTF-16BE "Test"
        0x00, 0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74,
        // UTF-16BE "en-US"
        0x00, 0x65, 0x00, 0x6E, 0x00, 0x2D, 0x00, 0x55, 0x00, 0x53,
      ]);

      final stream =
          RandomAccessReadDataStream.fromData(Uint8List.fromList(bytes));
      addTearDown(stream.close);

      final table = NamingTable()
        ..setOffset(0)
        ..setLength(bytes.length);

      table.read(null, stream);

      expect(table.getNameRecords(), hasLength(1));
      expect(table.languageTags, ['en-US']);

      final raw = table.getName(
        NameRecord.nameFontFamilyName,
        NameRecord.platformWindows,
        NameRecord.encodingWindowsUnicodeBmp,
        0x8000,
      );
      expect(raw, 'Test');

      expect(
        table.getNameByLanguageTag(
          NameRecord.nameFontFamilyName,
          NameRecord.platformWindows,
          NameRecord.encodingWindowsUnicodeBmp,
          'en-US',
        ),
        'Test',
      );

      expect(
        table.getNameByLanguageTag(
          NameRecord.nameFontFamilyName,
          NameRecord.platformWindows,
          NameRecord.encodingWindowsUnicodeBmp,
          'EN-us',
        ),
        'Test',
      );

      expect(
        table.getNameByLanguageTag(
          NameRecord.nameFontFamilyName,
          NameRecord.platformWindows,
          NameRecord.encodingWindowsUnicodeBmp,
          'fr-FR',
        ),
        isNull,
      );
    });

    test('reads format 3 records with 32-bit offsets', () {
      final storageOffset = 0x00000020;
      final bytes = Uint8List.fromList(<int>[
        0x00, 0x03, // format 3
        0x00, 0x01, // numberOfNameRecords
        (storageOffset >> 24) & 0xFF,
        (storageOffset >> 16) & 0xFF,
        (storageOffset >> 8) & 0xFF,
        storageOffset & 0xFF, // storageOffset (uint32)
        0x00, 0x03, // platformId: Windows
        0x00, 0x01, // encodingId: Unicode BMP
        0x04, 0x09, // languageId: en-US
        0x00, 0x04, // nameId: full font name
        0x00, 0x00, 0x00, 0x08, // stringLength: 8 bytes
        0x00, 0x00, 0x00, 0x00, // stringOffset: 0
        0x00, 0x00, // langTagCount: 0
        // padding up to storageOffset (32)
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        // string data (UTF-16BE "Demo")
        0x00, 0x44, 0x00, 0x65, 0x00, 0x6D, 0x00, 0x6F,
      ]);

      final stream =
          RandomAccessReadDataStream.fromData(Uint8List.fromList(bytes));
      addTearDown(stream.close);

      final table = NamingTable()
        ..setOffset(0)
        ..setLength(bytes.length);

      table.read(null, stream);

      final name = table.getName(
        NameRecord.nameFullFontName,
        NameRecord.platformWindows,
        NameRecord.encodingWindowsUnicodeBmp,
        NameRecord.languageWindowsEnUs,
      );
      expect(name, 'Demo');
      expect(table.languageTags, isEmpty);
    });
  });
}
