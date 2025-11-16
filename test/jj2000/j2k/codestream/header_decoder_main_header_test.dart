import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/jj2000/j2k/codestream/header_info.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/codestream/reader/header_decoder.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/util/is_random_access_io.dart';

void main() {
  group('HeaderDecoder.readMainHeader', () {
    test('parses SIZ marker and initialises geometry', () {
      final data = _buildMinimalCodestream();
      final io = ISRandomAccessIO(data);
      final headerInfo = HeaderInfo();

      final decoder = HeaderDecoder.readMainHeader(
        input: io,
        headerInfo: headerInfo,
      );

      expect(decoder.getNumComps(), equals(1));
      expect(decoder.getImgWidth(), equals(128));
      expect(decoder.getImgHeight(), equals(96));
      expect(decoder.getNomTileWidth(), equals(64));
      expect(decoder.getNomTileHeight(), equals(48));

      final siz = headerInfo.siz;
      expect(siz, isNotNull);
      expect(siz!.csiz, equals(1));
      expect(siz.xsiz - siz.x0siz, equals(128));
      expect(siz.ysiz - siz.y0siz, equals(96));

      expect(decoder.decSpec.dls.getDefault(), equals(0));

      final nextMarker = io.readUnsignedShort();
      expect(nextMarker, equals(0xff90)); // SOT marker

      io.close();
    });
  });
}

Uint8List _buildMinimalCodestream() {
  final builder = BytesBuilder();

  void writeMarker(int marker) {
    builder.add(<int>[(marker >> 8) & 0xff, marker & 0xff]);
  }

  void writeMarkerSegment(int marker, List<int> payload) {
    writeMarker(marker);
    builder.add(payload);
  }

  List<int> uint16(int value) => <int>[(value >> 8) & 0xff, value & 0xff];

  List<int> uint32(int value) => <int>[
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ];

  writeMarker(0xff4f); // SOC

  final sizSegment = BytesBuilder();
  sizSegment.add(uint16(38 + 3 * 1)); // Lsiz = 41
  sizSegment.add(uint16(0)); // Rsiz
  sizSegment.add(uint32(128)); // Xsiz
  sizSegment.add(uint32(96)); // Ysiz
  sizSegment.add(uint32(0)); // X0siz
  sizSegment.add(uint32(0)); // Y0siz
  sizSegment.add(uint32(64)); // XTsiz
  sizSegment.add(uint32(48)); // YTsiz
  sizSegment.add(uint32(0)); // XT0siz
  sizSegment.add(uint32(0)); // YT0siz
  sizSegment.add(uint16(1)); // Csiz
  sizSegment.add(<int>[0x07, 0x01, 0x01]); // 8-bit unsigned, no subsampling
  writeMarkerSegment(0xff51, sizSegment.takeBytes());

  final sotSegment = BytesBuilder();
  sotSegment.add(uint16(10)); // Lsot
  sotSegment.add(uint16(0)); // Isot
  sotSegment.add(uint32(0)); // Psot (unknown)
  sotSegment.add(<int>[0x00]); // TPsot
  sotSegment.add(<int>[0x01]); // TNsot
  writeMarkerSegment(0xff90, sotSegment.takeBytes());

  return builder.takeBytes();
}
