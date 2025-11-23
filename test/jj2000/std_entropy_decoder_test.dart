import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/decoder/DecoderSpecs.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/entropy/decoder/CodedCBlkDataSrcDec.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/entropy/decoder/DecLyrdCBlk.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/entropy/decoder/StdEntropyDecoder.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/image/Coord.dart';

import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/image/DataBlkInt.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/wavelet/subband.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/wavelet/synthesis/SubbandSyn.dart';
import 'package:test/test.dart';

void main() {
  group('StdEntropyDecoder parity', () {
    test('returns zeroed block when no passes exist', () {
      final block = DecLyrdCBlk()
        ..m = 0
        ..n = 0
        ..w = 2
        ..h = 2
        ..ulx = 1
        ..uly = 1
        ..nl = 0
        ..nTrunc = 0
        ..skipMSBP = 0
        ..prog = false
        ..dl = 0;

      final subband = SubbandSyn()
        ..isNode = false
        ..orientation = Subband.wtOrientLl
        ..resLvl = 0
        ..sbandIdx = 0
        ..w = block.w
        ..h = block.h;

      final src = _StubCodedCBlkDataSrcDec(block, subband);
      final specs = DecoderSpecs.basic(1, 1);
      final decoder = StdEntropyDecoder(
        src,
        specs,
        false,
        false,
        -1,
      )
        ..setTile(0, 0);

      final result = decoder.getCodeBlock(0, 0, 0, subband, null);
      expect(result, isA<DataBlkInt>());
      final out = result as DataBlkInt;
      expect(out.w, equals(2));
      expect(out.h, equals(2));
      expect(out.data, equals(<int>[0, 0, 0, 0]));
      expect(out.progressive, isFalse);
    });
  });
}

class _StubCodedCBlkDataSrcDec implements CodedCBlkDataSrcDec {
  _StubCodedCBlkDataSrcDec(this.block, this.subband);

  final DecLyrdCBlk block;
  final SubbandSyn subband;

  @override
  DecLyrdCBlk getCodeBlock(
    int component,
    int verticalCodeBlockIndex,
    int horizontalCodeBlockIndex,
    SubbandSyn subband,
    int firstLayer,
    int numLayers,
    DecLyrdCBlk? reuse,
  ) => block;

  @override
  int getCbULX() => 0;

  @override
  int getCbULY() => 0;

  @override
  int getCompImgHeight(int component, int resLevel) => block.h;

  @override
  int getCompImgWidth(int component, int resLevel) => block.w;

  @override
  int getCompSubsX(int component) => 1;

  @override
  int getCompSubsY(int component) => 1;

  @override
  int getImgHeight(int resLevel) => block.h;

  @override
  int getImgULX(int resLevel) => 0;

  @override
  int getImgULY(int resLevel) => 0;

  @override
  int getImgWidth(int resLevel) => block.w;

  @override
  int getNomRangeBits(int component) => 8;

  @override
  int getNomTileHeight() => block.h;

  @override
  int getNomTileWidth() => block.w;

  @override
  int getNumComps() => 1;

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

  @override
  int getResULX(int component, int resLevel) => 0;

  @override
  int getResULY(int component, int resLevel) => 0;

  @override
  SubbandSyn getSynSubbandTree(int tile, int component) => subband;

  @override
  Coord getTile(Coord? reuse) {
    final target = reuse ?? Coord();
    target
      ..x = 0
      ..y = 0;
    return target;
  }

  @override
  int getTileCompHeight(int tile, int component, int resLevel) => block.h;

  @override
  int getTileCompWidth(int tile, int component, int resLevel) => block.w;

  @override
  int getTileHeight(int resLevel) => block.h;

  @override
  int getTileIdx() => 0;

  @override
  int getTilePartULX() => 0;

  @override
  int getTilePartULY() => 0;

  @override
  int getTileWidth(int resLevel) => block.w;

  @override
  void nextTile() {
    throw StateError('single tile');
  }

  @override
  void setTile(int x, int y) {
    if (x != 0 || y != 0) {
      throw ArgumentError('single tile');
    }
  }
}


