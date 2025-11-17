import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/jj2000/j2k/codestream/markers.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/decoder/decoder.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/util/facility_manager.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/util/parameter_list.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/util/stream_msg_logger.dart';

import '../codestream/test_utils.dart';

void main() {
  group('Decoder.run', () {
    test('parses tile-parts sequentially after main header', () {
      final mainCod = buildCodMarkerPayload(
        scod: 0x00,
        sgcodPo: 0x00,
        sgcodNl: 0,
        sgcodMct: 0x00,
        spcodNdl: 1,
        spcodCw: 0x03,
        spcodCh: 0x03,
        spcodCs: 0x00,
        spcodT: 0x01,
      );
      final mainSqcd =
          (2 << Markers.SQCX_GB_SHIFT) | Markers.SQCX_NO_QUANTIZATION;
      final mainQcd = buildQcdMarkerPayload(
        sqcd: mainSqcd,
        stepBytes: <int>[
          5 << Markers.SQCX_EXP_SHIFT,
          4 << Markers.SQCX_EXP_SHIFT,
          4 << Markers.SQCX_EXP_SHIFT,
          4 << Markers.SQCX_EXP_SHIFT,
          3 << Markers.SQCX_EXP_SHIFT,
          3 << Markers.SQCX_EXP_SHIFT,
          3 << Markers.SQCX_EXP_SHIFT,
        ],
      );

      final builder = BytesBuilder();
      addMarker(builder, Markers.SOC);
      addMarkerSegment(
        builder,
        Markers.SIZ,
        buildSizMarkerPayload(
          xsize: 128,
          ysize: 96,
          tileWidth: 64,
          tileHeight: 48,
          numComps: 1,
          subsamplingX: const <int>[1],
          subsamplingY: const <int>[1],
          bitDepths: const <int>[0x07],
        ),
      );
      addMarkerSegment(builder, Markers.COD, mainCod);
      addMarkerSegment(builder, Markers.QCD, mainQcd);

      final tilePart0 = buildTilePart(
          tileIdx: 0, tilePartIdx: 0, numTileParts: 1, bodyLength: 5);
      final tilePart1 = buildTilePart(
          tileIdx: 1, tilePartIdx: 0, numTileParts: 1, bodyLength: 7);

      builder
        ..add(tilePart0.bytes)
        ..add(tilePart1.bytes);
      addMarker(builder, Markers.EOC);

      final codestream = builder.toBytes();
      final tempDir = Directory.systemTemp.createTempSync('decoder_run_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final inputFile = File('${tempDir.path}/stream.j2k')
        ..writeAsBytesSync(codestream);

      final params = ParameterList()
        ..put('i', inputFile.path)
        ..put('verbose', 'off')
        ..put('debug', 'off');

      final outBuffer = StringBuffer();
      final errBuffer = StringBuffer();
      final logger = StreamMsgLogger(outBuffer, errBuffer);

      final decoder = FacilityManager.runWithLogger(logger, () {
        final d = Decoder(params);
        d.run();
        return d;
      });

      expect(decoder.exitCode, equals(0));
      final headerDecoder = decoder.headerDecoder;
      expect(headerDecoder, isNotNull);
      expect(headerDecoder!.getNumComps(), equals(1));
      expect(headerDecoder.nTileParts.length, greaterThanOrEqualTo(2));
      expect(headerDecoder.nTileParts[0], equals(1));
      expect(headerDecoder.nTileParts[1], equals(1));
      expect(
          headerDecoder.getTilePartLengths(0), equals(<int>[tilePart0.psot]));
      expect(
          headerDecoder.getTilePartLengths(1), equals(<int>[tilePart1.psot]));
      expect(headerDecoder.getTilePartBodyLengths(0),
          equals(<int>[tilePart0.bodyLength]));
      expect(headerDecoder.getTilePartBodyLengths(1),
          equals(<int>[tilePart1.bodyLength]));
      expect(headerDecoder.getTilePartDataOffsets(0), isNotNull);
      expect(headerDecoder.getTilePartDataOffsets(0)!.length, equals(1));
      expect(headerDecoder.getTilePartDataOffsets(1), isNotNull);
      expect(headerDecoder.getTilePartDataOffsets(1)!.length, equals(1));

      expect(decoder.bitstreamReader, isNotNull);
      expect(decoder.entropyDecoder, isNotNull);
      expect(decoder.dequantizer, isNotNull);
      expect(decoder.inverseWT, isNotNull);
      expect(decoder.imageDataConverter, isNotNull);
      expect(decoder.componentTransformer, isNull);
      expect(decoder.imageDataSource, isNotNull);

      decoder.dispose();
    });
  });
}
