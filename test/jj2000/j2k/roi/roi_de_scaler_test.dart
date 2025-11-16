import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/jj2000/j2k/image/blk_img_data_src.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/image/coord.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/image/data_blk.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/image/data_blk_float.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/image/data_blk_int.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/roi/max_shift_spec.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/roi/rect_roi_spec.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/roi/rectangular_roi.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/roi/roi_de_scaler.dart';

void main() {
  group('ROIDeScaler', () {
    test('applies integer de-scaling outside ROI', () {
      final data = List<int>.generate(16, (index) => index);
      final block = DataBlkInt()
        ..ulx = 0
        ..uly = 0
        ..w = 4
        ..h = 4
        ..offset = 0
        ..scanw = 4
        ..setDataInt(List<int>.from(data, growable: false));

      final source = _SingleBlockSource(block);
      final maxShift = MaxShiftSpec(1, 1)
        ..setDefault(0)
        ..setTileCompVal(0, 0, 2);
      final rectSpec = RectROISpec(1, 1)
        ..setTileCompVal(
          0,
          0,
          RectangularROI(x0: 0, y0: 0, width: 2, height: 4),
        );

      final scaler = ROIDeScaler(source, maxShift, rectSpec: rectSpec);
      final result = scaler.getCompData(block, 0) as DataBlkInt;
      final values = result.getDataInt()!;

      expect(
        values,
        equals(<int>[
          0, 1, 0, 0,
          4, 5, 1, 1,
          8, 9, 2, 2,
          12, 13, 3, 3,
        ]),
      );
    });

    test('applies float de-scaling outside ROI', () {
      final data = Float32List.fromList(
        List<double>.generate(16, (index) => index.toDouble()),
      );
      final block = DataBlkFloat()
        ..ulx = 0
        ..uly = 0
        ..w = 4
        ..h = 4
        ..offset = 0
        ..scanw = 4
        ..setDataFloat(Float32List.fromList(data));

      final source = _SingleBlockSource(block);
      final maxShift = MaxShiftSpec(1, 1)
        ..setDefault(0)
        ..setTileCompVal(0, 0, 1);
      final rectSpec = RectROISpec(1, 1)
        ..setTileCompVal(
          0,
          0,
          RectangularROI(x0: 0, y0: 0, width: 1, height: 4),
        );

      final scaler = ROIDeScaler(source, maxShift, rectSpec: rectSpec);
      final result = scaler.getCompData(block, 0) as DataBlkFloat;
      final values = result.getDataFloat()!;

      expect(
        values,
        orderedEquals(<double>[
          0.0, 0.5, 1.0, 1.5,
          4.0, 2.5, 3.0, 3.5,
          8.0, 4.5, 5.0, 5.5,
          12.0, 6.5, 7.0, 7.5,
        ]),
      );
    });
  });
}

class _SingleBlockSource implements BlkImgDataSrc {
  _SingleBlockSource(this.block)
      : width = block.w,
        height = block.h;

  final DataBlk block;
  final int width;
  final int height;

  @override
  int getFixedPoint(int component) => 0;

  @override
  DataBlk getInternCompData(DataBlk target, int component) => block;

  @override
  DataBlk getCompData(DataBlk target, int component) => block;

  @override
  int getTileWidth() => width;

  @override
  int getTileHeight() => height;

  @override
  int getNomTileWidth() => width;

  @override
  int getNomTileHeight() => height;

  @override
  int getImgWidth() => width;

  @override
  int getImgHeight() => height;

  @override
  int getNumComps() => 1;

  @override
  int getCompSubsX(int component) => 1;

  @override
  int getCompSubsY(int component) => 1;

  @override
  int getTileCompWidth(int tile, int component) => width;

  @override
  int getTileCompHeight(int tile, int component) => height;

  @override
  int getCompImgWidth(int component) => width;

  @override
  int getCompImgHeight(int component) => height;

  @override
  int getNomRangeBits(int component) => 8;

  @override
  void setTile(int x, int y) {
    if (x != 0 || y != 0) {
      throw ArgumentError('Only tile (0,0) is available in test source');
    }
  }

  @override
  void nextTile() {
    throw StateError('No additional tiles in test source');
  }

  @override
  Coord getTile(Coord? reuse) {
    final coord = reuse ?? Coord();
    coord
      ..x = 0
      ..y = 0;
    return coord;
  }

  @override
  int getTileIdx() => 0;

  @override
  int getCompULX(int component) => 0;

  @override
  int getCompULY(int component) => 0;

  @override
  int getTilePartULX() => 0;

  @override
  int getTilePartULY() => 0;

  @override
  int getImgULX() => 0;

  @override
  int getImgULY() => 0;

  @override
  Coord getNumTilesCoord(Coord? reuse) {
    final coord = reuse ?? Coord();
    coord
      ..x = 1
      ..y = 1;
    return coord;
  }

  @override
  int getNumTiles() => 1;
}
