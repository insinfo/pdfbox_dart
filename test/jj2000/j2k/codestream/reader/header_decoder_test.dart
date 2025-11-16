import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/jj2000/j2k/codestream/header_info.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/codestream/reader/header_decoder.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/decoder/decoder_specs.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/image/coord.dart';

void main() {
  group('HeaderDecoder.parsePocMarker', () {
    test('populates decSpec.pcs for main header', () {
      final specs = DecoderSpecs.basic(1, 3);
      final info = HeaderInfo();
      final decoder = HeaderDecoder.placeholder(
        decSpec: specs,
        headerInfo: info,
        numComps: 3,
      );

      final payload = Uint8List.fromList(<int>[
        0x00,
        0x09,
        0x00,
        0x00,
        0x00,
        0x02,
        0x01,
        0x03,
        0x01,
      ]);

      decoder.parsePocMarker(payload, isMainHeader: true, tileIdx: 0);

      final pocSpec = specs.pcs.getDefault();
      expect(pocSpec, isNotNull);
      expect(pocSpec, hasLength(1));
      expect(pocSpec![0], equals(<int>[0, 0, 2, 1, 3, 1]));

      final pocInfo = info.poc['main'];
      expect(pocInfo, isNotNull);
      expect(pocInfo!.rspoc, equals(<int>[0]));
      expect(pocInfo.cspoc, equals(<int>[0]));
      expect(pocInfo.lyepoc, equals(<int>[2]));
      expect(pocInfo.repoc, equals(<int>[1]));
      expect(pocInfo.cepoc, equals(<int>[3]));
      expect(pocInfo.ppoc, equals(<int>[1]));
    });

    test('applies tile specific progression changes', () {
      final specs = DecoderSpecs.basic(2, 4);
      final info = HeaderInfo();
      final decoder = HeaderDecoder.placeholder(
        decSpec: specs,
        headerInfo: info,
        numComps: 4,
      );

      final mainPayload = Uint8List.fromList(<int>[
        0x00,
        0x09,
        0x00,
        0x00,
        0x00,
        0x02,
        0x01,
        0x03,
        0x01,
      ]);
      decoder.parsePocMarker(mainPayload, isMainHeader: true, tileIdx: 0);

      final tilePayload = Uint8List.fromList(<int>[
        0x00,
        0x09,
        0x01,
        0x02,
        0x00,
        0x04,
        0x03,
        0x05,
        0x03,
      ]);

      decoder.parsePocMarker(tilePayload, isMainHeader: false, tileIdx: 0);

      final tileSpec = specs.pcs.getTileDef(0);
      expect(tileSpec, isNotNull);
      expect(tileSpec, hasLength(1));
      expect(tileSpec![0], equals(<int>[1, 2, 4, 3, 5, 3]));

      final pocInfo = info.poc['t0'];
      expect(pocInfo, isNotNull);
      expect(pocInfo!.rspoc, equals(<int>[1]));
      expect(pocInfo.cspoc, equals(<int>[2]));
      expect(pocInfo.lyepoc, equals(<int>[4]));
      expect(pocInfo.repoc, equals(<int>[3]));
      expect(pocInfo.cepoc, equals(<int>[5]));
      expect(pocInfo.ppoc, equals(<int>[3]));
    });
  });

  group('HeaderDecoder tile-part metadata', () {
    test('aggregates Psot and exposes packed packet headers', () {
      final specs = DecoderSpecs.basic(2, 1);
      final info = HeaderInfo();
      final decoder = HeaderDecoder(
        decSpec: specs,
        headerInfo: info,
        numComps: 1,
        imgWidth: 0,
        imgHeight: 0,
        imgULX: 0,
        imgULY: 0,
        nomTileWidth: 0,
        nomTileHeight: 0,
        cbULX: 0,
        cbULY: 0,
        compSubsX: const <int>[1],
        compSubsY: const <int>[1],
        maxCompImgWidth: 0,
        maxCompImgHeight: 0,
        tilingOrigin: Coord(0, 0),
      );

      decoder.registerTilePartLength(0, 0, 150);
      decoder.registerTilePartLength(0, 1, 200);
      expect(decoder.nTileParts, contains(2));
      expect(decoder.getTileTotalLength(0), 350);

      decoder.registerTilePartLength(0, 1, 0);
      expect(decoder.getTileTotalLength(0), isNull);

      decoder.registerTilePartLength(0, 1, 200);
      expect(decoder.getTileTotalLength(0), 350);
      final packed = Uint8List.fromList(<int>[1, 2, 3]);
      decoder.registerPackedPacketHeaders(0, packed);
      expect(specs.pphs.getTileDef(0), isTrue);

      final retrieved = decoder.getPackedPacketHeaders(0);
      expect(retrieved, isNotNull);
      expect(retrieved, equals(packed));
    });

    test('parseSotMarker registers tile-part metadata', () {
      final specs = DecoderSpecs.basic(2, 1);
      final info = HeaderInfo();
      final decoder = HeaderDecoder.placeholder(
        decSpec: specs,
        headerInfo: info,
        numComps: 1,
      );

      final payload = Uint8List.fromList(<int>[0x00, 0x0A, 0x00, 0x01, 0x00, 0x00, 0x00, 0x64, 0x02, 0x05]);
      decoder.parseSotMarker(payload);

      final sot = info.sot['t1_tp2'];
      expect(sot, isNotNull);
      expect(sot!.psot, 100);
      expect(decoder.getTileTotalLength(1), 100);
      expect(decoder.nTileParts.length, greaterThan(1));
      expect(decoder.nTileParts[1], greaterThanOrEqualTo(3));
    });

    test('parsePpmMarker assembles packed headers per tile', () {
      final specs = DecoderSpecs.basic(2, 1);
      final info = HeaderInfo();
      final decoder = HeaderDecoder.placeholder(
        decSpec: specs,
        headerInfo: info,
        numComps: 1,
      );

      decoder.setTileOfTileParts(0);
      decoder.setTileOfTileParts(1);

      final ppmPayload = Uint8List.fromList(<int>[
        0x00,
        0x0E,
        0x00,
        0x00,
        0x00,
        0x00,
        0x02,
        0xAA,
        0xBB,
        0x00,
        0x00,
        0x00,
        0x01,
        0xCC,
      ]);

      decoder.parsePpmMarker(ppmPayload);

      final tile0 = decoder.getPackedPacketHeaders(0);
      final tile1 = decoder.getPackedPacketHeaders(1);

      expect(tile0, equals(Uint8List.fromList(<int>[0xAA, 0xBB])));
      expect(tile1, equals(Uint8List.fromList(<int>[0xCC])));
      expect(specs.pphs.getDefault(), isTrue);
    });

    test('parsePptMarker appends headers for each tile part', () {
      final specs = DecoderSpecs.basic(1, 1);
      final info = HeaderInfo();
      final decoder = HeaderDecoder.placeholder(
        decSpec: specs,
        headerInfo: info,
        numComps: 1,
      );

      final sotPayload = Uint8List.fromList(<int>[0x00, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x01]);
      decoder.parseSotMarker(sotPayload);

      decoder.parsePptMarker(
        Uint8List.fromList(<int>[0x00, 0x04, 0x00, 0x01]),
        tileIdx: 0,
        tilePartIdx: 0,
      );
      decoder.parsePptMarker(
        Uint8List.fromList(<int>[0x00, 0x05, 0x01, 0x02, 0x03]),
        tileIdx: 0,
        tilePartIdx: 0,
      );

      final packed = decoder.getPackedPacketHeaders(0);
      expect(packed, equals(Uint8List.fromList(<int>[0x01, 0x02, 0x03])));
      expect(specs.pphs.getTileDef(0), isTrue);
    });
  });
}
