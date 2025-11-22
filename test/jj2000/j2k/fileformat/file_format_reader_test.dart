import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/fileformat/file_format_boxes.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/fileformat/file_format_reader.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/is_random_access_io.dart';

void main() {
  group('FileFormatReader', () {
    test('accepts raw codestreams', () {
      final data = Uint8List.fromList(<int>[
        0xff,
        0x4f,
        0xff,
        0x90,
        0x00,
        0x00,
        0x00,
        0x00,
        0xff,
        0xd9,
        0x00,
        0x00,
      ]);
      final io = ISRandomAccessIO(data);

      final reader = FileFormatReader(io);
      expect(() => reader.readFileFormat(), returnsNormally);
      expect(reader.JP2FFUsed, isFalse);

      io.close();
    });

    test('locates contiguous codestream box', () {
      final data = _buildMinimalJp2();
      final io = ISRandomAccessIO(data);
      final reader = FileFormatReader(io);

      reader.readFileFormat();

      expect(reader.JP2FFUsed, isTrue);
      expect(reader.getFirstCodeStreamPos(), equals(48));
      expect(reader.getFirstCodeStreamLength(), equals(12));

      io.close();
    });
  });
}

Uint8List _buildMinimalJp2() {
  final builder = BytesBuilder();

  void writeInt(int value) {
    builder.add(<int>[
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }

  // Signature box
  writeInt(12);
  writeInt(FileFormatBoxes.jp2SignatureBox);
  writeInt(0x0d0a870a);

  // File Type box with one compatibility entry
  writeInt(20);
  writeInt(FileFormatBoxes.fileTypeBox);
  writeInt(FileFormatBoxes.ftBr);
  writeInt(0);
  writeInt(FileFormatBoxes.ftBr);

  // Empty JP2 header box
  writeInt(8);
  writeInt(FileFormatBoxes.jp2HeaderBox);

  // Contiguous codestream box containing a minimal codestream (SOC + EOC)
  writeInt(12);
  writeInt(FileFormatBoxes.contiguousCodestreamBox);
  builder.add(<int>[0xff, 0x4f, 0xff, 0xd9]);

  return builder.takeBytes();
}
