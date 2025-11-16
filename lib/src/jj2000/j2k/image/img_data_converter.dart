import 'dart:typed_data';

import 'blk_img_data_src.dart';
import 'data_blk.dart';
import 'data_blk_float.dart';
import 'data_blk_int.dart';
import 'img_data_adapter.dart';

/// Converts between integer and floating-point block representations on demand.
class ImgDataConverter extends ImgDataAdapter implements BlkImgDataSrc {
  ImgDataConverter(BlkImgDataSrc source, [int fixedPoint = 0])
      : _fixedPoint = fixedPoint,
        _source = source,
        super(source);

  final BlkImgDataSrc _source;
  final DataBlkInt _intScratch = DataBlkInt();
  int _fixedPoint;

  @override
  int getFixedPoint(int component) => _fixedPoint;

  @override
  DataBlk getCompData(DataBlk block, int component) =>
      _resolveData(block, component, false);

  @override
  DataBlk getInternCompData(DataBlk block, int component) =>
      _resolveData(block, component, true);

  DataBlk _resolveData(DataBlk block, int component, bool intern) {
    final desiredType = block.getDataType();
    DataBlk request;

    if (desiredType == _intScratch.getDataType()) {
      request = block;
    } else {
      request = _intScratch
        ..ulx = block.ulx
        ..uly = block.uly
        ..w = block.w
        ..h = block.h;
    }

    final DataBlk acquired = intern
        ? _source.getInternCompData(request, component)
        : _source.getCompData(request, component);

    if (acquired.getDataType() == desiredType) {
      if (!identical(acquired, block)) {
        block
          ..ulx = acquired.ulx
          ..uly = acquired.uly
          ..w = acquired.w
          ..h = acquired.h
          ..offset = acquired.offset
          ..scanw = acquired.scanw
          ..progressive = acquired.progressive
          ..setData(acquired.getData());
      }
      if (acquired is DataBlkInt) {
        _fixedPoint = _source.getFixedPoint(component);
      }
      return acquired;
    }

    if (desiredType == DataBlk.typeFloat && acquired is DataBlkInt) {
      return _convertIntToFloat(block, acquired, component);
    }

    if (desiredType == DataBlk.typeInt && acquired is DataBlkFloat) {
      return _convertFloatToInt(block, acquired, component);
    }

    throw ArgumentError(
      'Unsupported conversion: source=${acquired.getDataType()} target=$desiredType',
    );
  }

  DataBlk _convertIntToFloat(
    DataBlk target,
    DataBlkInt source,
    int component,
  ) {
    final intData = source.getDataInt();
    if (intData == null) {
      throw StateError('Integer block payload missing');
    }

    final floatBlock = target is DataBlkFloat ? target : DataBlkFloat();
    final width = source.w;
    final height = source.h;

    floatBlock
      ..ulx = source.ulx
      ..uly = source.uly
      ..w = width
      ..h = height
      ..offset = 0
      ..scanw = width
      ..progressive = source.progressive;

    final required = width * height;
    var floatData = floatBlock.getDataFloat();
    if (floatData == null || floatData.length < required) {
      floatData = Float32List(required);
      floatBlock.setData(floatData);
    }

    final shift = _source.getFixedPoint(component);
    if (shift != _fixedPoint) {
      _fixedPoint = shift;
    }
    final scale = shift == 0 ? 1.0 : 1.0 / (1 << shift);

    var srcIndex = source.offset;
    var dstIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowEnd = dstIndex + width;
      while (dstIndex < rowEnd) {
        floatData[dstIndex++] = intData[srcIndex++] * scale;
      }
      srcIndex += source.scanw - width;
    }

    return floatBlock;
  }

  DataBlk _convertFloatToInt(
    DataBlk target,
    DataBlkFloat source,
    int component,
  ) {
    final floatData = source.getDataFloat();
    if (floatData == null) {
      throw StateError('Float block payload missing');
    }

    final intBlock = target is DataBlkInt ? target : DataBlkInt();
    final width = source.w;
    final height = source.h;

    intBlock
      ..ulx = source.ulx
      ..uly = source.uly
      ..w = width
      ..h = height
      ..offset = 0
      ..scanw = width
      ..progressive = source.progressive;

    final required = width * height;
    var intData = intBlock.getDataInt();
    if (intData == null || intData.length < required) {
      intData = List<int>.filled(required, 0, growable: false);
      intBlock.setDataInt(intData);
    }

    final shift = _fixedPoint;
    final scale = shift == 0 ? 1.0 : (1 << shift).toDouble();

    var srcIndex = source.offset;
    var dstIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowEnd = dstIndex + width;
      while (dstIndex < rowEnd) {
        final value = floatData[srcIndex++] * scale;
        intData[dstIndex++] =
            value >= 0 ? (value + 0.5).floor() : (value - 0.5).floor();
      }
      srcIndex += source.scanw - width;
    }

    return intBlock;
  }
}
