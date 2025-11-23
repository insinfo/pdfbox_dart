import 'dart:typed_data';



import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/ISRandomAccessIO.dart';
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/codestream/HeaderInfo.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/codestream/reader/BitstreamReaderAgent.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/codestream/reader/HeaderDecoder.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/decoder/DecoderSpecs.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/image/Coord.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/quantization/dequantizer/StdDequantizerParams.dart';

import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/ParameterList.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/wavelet/synthesis/SynWtFilter.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/wavelet/synthesis/SynWtFilterIntLift5x3.dart';

void main() {
  group('FileBitstreamReaderAgent multi tile-part handling', () {
    test('consumes packet budgets across tile-parts', () {
      final decSpec = DecoderSpecs.basic(1, 1);
      decSpec.nls.setTileDef(0, 4);
      final reversibleFilter = SynWTFilterIntLift5x3();
      decSpec.wfs.setTileCompVal(0, 0, <List<SynWTFilter>>[
        <SynWTFilter>[reversibleFilter],
        <SynWTFilter>[reversibleFilter],
      ]);
      decSpec.dls.setTileCompVal(0, 0, 0);
      final defaultQuant = decSpec.qsss.getDefault();
      if (defaultQuant == null) {
        fail('DecoderSpecs.basic should provide default quantization parameters');
      }
      final quantParams = StdDequantizerParams(
        exp: defaultQuant.exp.isNotEmpty ? defaultQuant.exp : <List<int>>[<int>[0]],
        nStep: defaultQuant.nStep,
      );
      decSpec.qsss.setTileCompVal(0, 0, quantParams);
      decSpec.gbs.setTileCompVal(0, 0, 1);

      final headerInfo = HeaderInfo();
      final siz = headerInfo.getNewSIZ()
        ..lsiz = 38
        ..rsiz = 0
        ..xsiz = 32
        ..ysiz = 32
        ..x0siz = 0
        ..y0siz = 0
        ..xtsiz = 32
        ..ytsiz = 32
        ..xt0siz = 0
        ..yt0siz = 0
        ..csiz = 1
        ..ssiz = <int>[8]
        ..xrsiz = <int>[1]
        ..yrsiz = <int>[1];
      headerInfo.siz = siz;

      final headerDecoder = HeaderDecoder(
        decSpec: decSpec,
        headerInfo: headerInfo,
        numComps: 1,
        imgWidth: 32,
        imgHeight: 32,
        imgULX: 0,
        imgULY: 0,
        nomTileWidth: 32,
        nomTileHeight: 32,
        cbULX: 0,
        cbULY: 0,
        compSubsX: const <int>[1],
        compSubsY: const <int>[1],
        maxCompImgWidth: 32,
        maxCompImgHeight: 32,
        tilingOrigin: Coord(0, 0),
      );

      headerDecoder.parseSotMarker(
        Uint8List.fromList(<int>[0x00, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x02]),
      );
      headerDecoder.parseSotMarker(
        Uint8List.fromList(<int>[0x00, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1E, 0x01, 0x02]),
      );
      headerDecoder.registerTilePartDataOffset(0, 0, 16);
      headerDecoder.registerTilePartBodyLength(0, 0, 20);
      headerDecoder.registerTilePartDataOffset(0, 1, 64);
      headerDecoder.registerTilePartBodyLength(0, 1, 28);

      final input = ISRandomAccessIO(Uint8List(128));
      final parameters = ParameterList()
        ..put('trunc', 'off');
      final agent = FileBitstreamReaderAgent(
        headerDecoder,
        input,
        decSpec,
        parameters,
        false,
        headerInfo,
      );

      final consumptions = <int>[10, 14, 12, 18];
      final transitions = <String>[];
      var packetIndex = 0;
      var currentTilePart = 0;

      agent.debugSetPacketSimulation(
        consumptions.length,
        (int layer, int resolution, int component, int precinct, List<int> remainingBytes) {
          final tileBudget = remainingBytes[agent.getTileIdx()];
          final consumption = consumptions[packetIndex++];
          final updated = tileBudget - consumption;
          remainingBytes[agent.getTileIdx()] = updated;
          if (updated <= 0) {
            transitions.add('tilePart$currentTilePart-exhausted');
            currentTilePart++;
            return true;
          }
          transitions.add('tilePart$currentTilePart-consumed$consumption');
          return false;
        },
      );

      headerDecoder.registerPackedPacketHeaders(0, Uint8List.fromList(<int>[1, 2, 3]));

      // Ensure tile budgets observed during decoding.
      agent.setTile(0, 0);
      expect(input.getPos(), equals(64));

      agent.debugClearPacketSimulation();
      input.close();

      expect(transitions, contains('tilePart0-consumed10'));
      expect(transitions, contains('tilePart0-exhausted'));
      expect(transitions, contains('tilePart1-consumed12'));
      expect(transitions.last, equals('tilePart1-exhausted'));
      expect(decSpec.pphs.getTileDef(0), isTrue);
      expect(headerDecoder.getTilePartLengths(0), equals(<int>[24, 30]));
    });
  });
}

