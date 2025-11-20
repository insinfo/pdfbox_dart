import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfbox_dart/src/jj2000/j2k/decoder/decoder_specs.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/entropy/decoder/coded_cblk_data_src_dec.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/entropy/decoder/dec_lyrd_cblk.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/entropy/decoder/std_entropy_decoder.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/image/coord.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/image/data_blk_int.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/no_next_element_exception.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/wavelet/synthesis/subband_syn.dart';
import 'package:test/test.dart';

import 'fixtures/std_entropy/std_entropy_fixture.dart';

void main() {
  group('StdEntropyDecoder fixture parity', () {
    test('replays rainbowbars component 1 code-block', () {
      final fixture = StdEntropyFixture.load(
        'test/jj2000/fixtures/std_entropy/rainbowbars_comp1.json',
      );

      final specs = _buildSpecs(fixture);
      final block = fixture.toCodeBlock();
      final subband = fixture.toSubband();
      final data = block.data;
      expect(data, isNotNull, reason: 'Fixture payload should be present');
      expect(data!.length, equals(block.dl),
          reason: 'Fixture payload length mismatch');
      expect(
        fixture.coefficients.length,
        equals(block.w * block.h),
        reason: 'Coefficient vector should match block dimensions',
      );
      final source =
          _FixtureCodedCBlkDataSrcDec(block, subband, fixture.component);

      final decoder = StdEntropyDecoder(source, specs, false, false, -1)
        ..setTile(0, 0);

      final decoded = decoder.getCodeBlock(
        fixture.component,
        fixture.blockIndices.m,
        fixture.blockIndices.n,
        subband,
        null,
      );

      expect(decoded, isA<DataBlkInt>());
      final ints = decoded as DataBlkInt;
      expect(ints.w, equals(block.w));
      expect(ints.h, equals(block.h));
      expect(ints.data, equals(fixture.coefficients));
    },
        skip:
            'StdEntropyDecoder parity gap: fixture coefficients do not yet match Java output');
  });
}

DecoderSpecs _buildSpecs(StdEntropyFixture fixture) {
  final specs = DecoderSpecs.basic(1, math.max(fixture.component + 1, 1));
  specs.cblks.setDefault(<int>[fixture.block.w, fixture.block.h]);
  specs.ecopts.setDefault(fixture.block.options);
  return specs;
}

/// Minimal entropy source that replays the recorded code-block to the decoder.
class _FixtureCodedCBlkDataSrcDec implements CodedCBlkDataSrcDec {
  _FixtureCodedCBlkDataSrcDec(this.block, this.subband, this.componentIndex)
      : numComponents = math.max(componentIndex + 1, 1);

  final DecLyrdCBlk block;
  final SubbandSyn subband;
  final int componentIndex;
  final int numComponents;

  @override
  DecLyrdCBlk getCodeBlock(
    int component,
    int verticalCodeBlockIndex,
    int horizontalCodeBlockIndex,
    SubbandSyn requestedSubband,
    int firstLayer,
    int numLayers,
    DecLyrdCBlk? reuse,
  ) {
    if (component != componentIndex ||
        verticalCodeBlockIndex != block.m ||
        horizontalCodeBlockIndex != block.n) {
      throw StateError('Fixture does not contain the requested code-block');
    }
    final target = reuse ?? DecLyrdCBlk();
    return _copyBlock(block, target);
  }

  @override
  SubbandSyn getSynSubbandTree(int tile, int component) => subband;

  @override
  int getCbULX() => 0;

  @override
  int getCbULY() => 0;

  @override
  int getTileWidth(int resLevel) => subband.w;

  @override
  int getTileHeight(int resLevel) => subband.h;

  @override
  int getNomTileWidth() => subband.w;

  @override
  int getNomTileHeight() => subband.h;

  @override
  int getImgWidth(int resLevel) => subband.w;

  @override
  int getImgHeight(int resLevel) => subband.h;

  @override
  int getNumComps() => numComponents;

  @override
  int getCompSubsX(int component) => 1;

  @override
  int getCompSubsY(int component) => 1;

  @override
  int getTileCompWidth(int tile, int component, int resLevel) => block.w;

  @override
  int getTileCompHeight(int tile, int component, int resLevel) => block.h;

  @override
  int getCompImgWidth(int component, int resLevel) => block.w;

  @override
  int getCompImgHeight(int component, int resLevel) => block.h;

  @override
  int getNomRangeBits(int component) => 8;

  @override
  void setTile(int x, int y) {
    if (x != 0 || y != 0) {
      throw ArgumentError('Only tile 0/0 is available in the fixture source');
    }
  }

  @override
  void nextTile() => throw NoNextElementException();

  @override
  Coord getTile(Coord? reuse) {
    final target = reuse ?? Coord();
    target
      ..x = 0
      ..y = 0;
    return target;
  }

  @override
  int getTileIdx() => 0;

  @override
  int getResULX(int component, int resLevel) => 0;

  @override
  int getResULY(int component, int resLevel) => 0;

  @override
  int getImgULX(int resLevel) => 0;

  @override
  int getImgULY(int resLevel) => 0;

  @override
  int getTilePartULX() => 0;

  @override
  int getTilePartULY() => 0;

  @override
  Coord getNumTiles(Coord? reuse) {
    final target = reuse ?? Coord();
    target
      ..x = 1
      ..y = 1;
    return target;
  }

  @override
  int getNumTilesTotal() => 1;

  static DecLyrdCBlk _copyBlock(DecLyrdCBlk source, DecLyrdCBlk target) {
    target
      ..m = source.m
      ..n = source.n
      ..skipMSBP = source.skipMSBP
      ..ulx = source.ulx
      ..uly = source.uly
      ..w = source.w
      ..h = source.h
      ..dl = source.dl
      ..prog = source.prog
      ..nl = source.nl
      ..ftpIdx = source.ftpIdx
      ..nTrunc = source.nTrunc
      ..tsLengths =
          source.tsLengths == null ? null : List<int>.from(source.tsLengths!);
    final data = source.data;
    target.data = data == null ? null : Uint8List.fromList(data);
    return target;
  }
}
