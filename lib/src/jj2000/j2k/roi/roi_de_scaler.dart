import '../image/blk_img_data_src.dart';
import '../image/blk_img_data_src_adapter.dart';
import '../image/data_blk.dart';
import '../image/data_blk_float.dart';
import '../image/data_blk_int.dart';
import 'max_shift_spec.dart';
import 'rect_roi_mask_generator.dart';
import 'rect_roi_spec.dart';
import 'roi_mask_generator.dart';

/// Restores the original magnitude relationship between ROI and background samples.
class ROIDeScaler extends BlkImgDataSrcAdapter {
  ROIDeScaler(
    BlkImgDataSrc source,
    this._roiSpec, {
    ROIMaskGenerator? maskGenerator,
    RectROISpec? rectSpec,
  })  : _maskGenerator = maskGenerator ??
            (rectSpec != null
                ? RectROIMaskGenerator(spec: rectSpec)
                : const NoOpROIMaskGenerator()),
        super(source);

  final MaxShiftSpec _roiSpec;
  final ROIMaskGenerator _maskGenerator;
  List<int> _mask = <int>[];

  @override
  DataBlk getCompData(DataBlk block, int component) {
    final data = super.getCompData(block, component);
    return _applyDescale(data, component);
  }

  @override
  DataBlk getInternCompData(DataBlk block, int component) {
    final data = super.getInternCompData(block, component);
    return _applyDescale(data, component);
  }

  DataBlk _applyDescale(DataBlk block, int component) {
    final tile = getTileIdx();
    final shift = _roiSpec.shiftFor(tile, component);
    if (shift <= 0 || block.w == 0 || block.h == 0) {
      return block;
    }

    final total = block.w * block.h;
    if (_mask.length != total) {
      _mask = List<int>.filled(total, 0, growable: false);
    }

    _mask.fillRange(0, total, 0);

    _maskGenerator.fillMask(
      tileIndex: tile,
      component: component,
      block: block,
      mask: _mask,
    );

    if (block is DataBlkInt) {
      _descaleIntegers(block, shift);
      return block;
    }

    if (block is DataBlkFloat) {
      _descaleFloats(block, shift);
      return block;
    }

    throw ArgumentError('Unsupported data type for ROI de-scaling: ${block.getDataType()}');
  }

  void _descaleIntegers(DataBlkInt block, int shift) {
    final data = block.getDataInt();
    if (data == null) {
      return;
    }
    final stride = block.scanw;
    final width = block.w;
    final height = block.h;
    final offset = block.offset;

    var maskIndex = 0;
    var rowBase = offset;
    for (var row = 0; row < height; row++) {
      var index = rowBase;
      for (var col = 0; col < width; col++, index++, maskIndex++) {
        if (_mask[maskIndex] == 0) {
          data[index] >>= shift;
        }
      }
      rowBase += stride;
    }
  }

  void _descaleFloats(DataBlkFloat block, int shift) {
    final data = block.getDataFloat();
    if (data == null) {
      return;
    }
    final stride = block.scanw;
    final width = block.w;
    final height = block.h;
    final offset = block.offset;
    final factor = 1 << shift;
    final scale = 1.0 / factor;

    var maskIndex = 0;
    var rowBase = offset;
    for (var row = 0; row < height; row++) {
      var index = rowBase;
      for (var col = 0; col < width; col++, index++, maskIndex++) {
        if (_mask[maskIndex] == 0) {
          data[index] = data[index] * scale;
        }
      }
      rowBase += stride;
    }
  }
}
