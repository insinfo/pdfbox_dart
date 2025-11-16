import 'dart:math' as math;
import 'dart:typed_data';

import '../../decoder/decoder_specs.dart';
import '../../image/data_blk.dart';
import '../../image/data_blk_float.dart';
import '../../image/data_blk_int.dart';
import '../../wavelet/synthesis/subband_syn.dart';
import '../guard_bits_spec.dart';
import '../quant_step_size_spec.dart';
import '../quant_type_spec.dart';
import 'cblk_quant_data_src_dec.dart';
import 'dequantizer.dart';
import 'std_dequantizer_params.dart';

/// Scalar dead-zone dequantizer mirroring JJ2000's implementation.
class StdDequantizer extends Dequantizer {
  StdDequantizer(
    CBlkQuantDataSrcDec src,
    List<int> utrb,
    DecoderSpecs decSpec,
  )   : qts = decSpec.qts,
        qsss = decSpec.qsss,
        gbs = decSpec.gbs,
        super(src, utrb, decSpec);

  final QuantTypeSpec qts;
  final QuantStepSizeSpec qsss;
  final GuardBitsSpec gbs;
  DataBlkInt? _intBuffer;

  @override
  int getFixedPoint(int component) => 0;

  @override
  DataBlk? getCodeBlock(
    int component,
    int verticalCodeBlockIndex,
    int horizontalCodeBlockIndex,
    SubbandSyn subband,
    DataBlk? block,
  ) =>
      getInternCodeBlock(
        component,
        verticalCodeBlockIndex,
        horizontalCodeBlockIndex,
        subband,
        block,
      );

  @override
  DataBlk? getInternCodeBlock(
    int component,
    int verticalCodeBlockIndex,
    int horizontalCodeBlockIndex,
    SubbandSyn subband,
    DataBlk? block,
  ) {
    final tileIdx = src.getTileIdx();
    final reversible = qts.isReversible(tileIdx, component);
    final derived = qts.isDerived(tileIdx, component);
    final params = qsss.getTileCompVal(tileIdx, component);
    if (params == null) {
      throw StateError(
        'Missing quantization step sizes for tile=$tileIdx component=$component',
      );
    }
    final guardBits = gbs.getTileCompVal(tileIdx, component) ?? 0;

    final outType = block?.getDataType() ?? DataBlk.typeInt;
    if (reversible && outType != DataBlk.typeInt) {
      throw ArgumentError('Reversible quantizations must use int data');
    }

    switch (outType) {
      case DataBlk.typeInt:
        final quantized = src.getCodeBlock(
          component,
          verticalCodeBlockIndex,
          horizontalCodeBlockIndex,
          subband,
          block,
        );
        if (quantized is! DataBlkInt) {
          throw StateError('Expected integer data block');
        }
        _ensureSubbandMagBits(
          subband,
          guardBits,
          component,
          params,
          derived,
        );
        _dequantizeIntBlock(
          quantized,
          subband,
          component,
          reversible,
          derived,
          params,
        );
        return quantized;

      case DataBlk.typeFloat:
        _intBuffer = src.getInternCodeBlock(
          component,
          verticalCodeBlockIndex,
          horizontalCodeBlockIndex,
          subband,
          _intBuffer,
        ) as DataBlkInt;
        final quantized = _intBuffer!;
        final outBlock =
            (block is DataBlkFloat ? block : DataBlkFloat())
              ..progressive = quantized.progressive;
        _prepareFloatBlock(outBlock, quantized);
        _ensureSubbandMagBits(
          subband,
          guardBits,
          component,
          params,
          derived,
        );
        _dequantizeFloatBlock(
          quantized,
          outBlock,
          subband,
          component,
          derived,
          params,
        );
        return outBlock;

      default:
        throw UnsupportedError('Unsupported data type: $outType');
    }
  }

  void _ensureSubbandMagBits(
    SubbandSyn subband,
    int guardBits,
    int component,
    StdDequantizerParams params,
    bool derived,
  ) {
    if (subband.magBits > 0) {
      return;
    }

    final expBits = _resolveExponentBits(params, subband, derived);
    final baseBits = math.max(
      expBits ?? 0,
      rb[component] + subband.anGainExp,
    );
    subband.magBits = baseBits + guardBits;
  }

  int? _resolveExponentBits(
    StdDequantizerParams params,
    SubbandSyn subband,
    bool derived,
  ) {
    final expTable = params.exp;
    if (expTable.isEmpty) {
      return null;
    }

    final direct = _lookupExponent(expTable, subband.resLvl, subband.sbandIdx);
    if (direct != null) {
      return direct;
    }

    if (derived) {
      final fallback = _lookupExponent(expTable, 0, 0);
      if (fallback != null) {
        return fallback;
      }
    }

    for (var res = 0; res < expTable.length; res++) {
      final row = expTable[res];
      for (var idx = 0; idx < row.length; idx++) {
        final value = row[idx];
        if (value > 0) {
          return value;
        }
      }
    }

    return null;
  }

  int? _lookupExponent(List<List<int>> table, int res, int band) {
    if (res < 0 || res >= table.length) {
      return null;
    }
    final row = table[res];
    if (band < 0 || band >= row.length) {
      return null;
    }
    final value = row[band];
    return value > 0 ? value : null;
  }

  void _dequantizeIntBlock(
    DataBlkInt block,
    SubbandSyn subband,
    int component,
    bool reversible,
    bool derived,
    StdDequantizerParams params,
  ) {
    final data = block.getDataInt();
    if (data == null) {
      throw StateError('Quantized block missing payload');
    }

    final shiftBits = 31 - subband.magBits;

    if (reversible) {
      for (var i = data.length - 1; i >= 0; i--) {
        final temp = data[i];
        data[i] = temp >= 0
            ? temp >> shiftBits
            : -((temp & 0x7fffffff) >> shiftBits);
      }
      return;
    }

    final step = _computeStep(params, derived, subband, component, shiftBits);
    for (var i = data.length - 1; i >= 0; i--) {
      final temp = data[i];
      final value = temp >= 0
          ? temp * step
          : -(temp & 0x7fffffff) * step;
      data[i] = value.toInt();
    }
  }

  void _dequantizeFloatBlock(
    DataBlkInt quantized,
    DataBlkFloat outBlock,
    SubbandSyn subband,
    int component,
    bool derived,
    StdDequantizerParams params,
  ) {
    final inData = quantized.getDataInt();
    final outData = outBlock.getDataFloat();
    if (inData == null || outData == null) {
      throw StateError('Unable to access wavelet data buffers');
    }

    final step = _computeStep(
      params,
      derived,
      subband,
      component,
      31 - subband.magBits,
    );

    final width = quantized.w;
    final height = quantized.h;
    final inOffset = quantized.offset;
    final inScanw = quantized.scanw;

    for (var row = 0; row < height; row++) {
      final inBase = inOffset + row * inScanw;
      final outBase = row * width;
      for (var col = 0; col < width; col++) {
        final temp = inData[inBase + col];
        final double value = temp >= 0
            ? temp * step
            : -(temp & 0x7fffffff) * step;
        outData[outBase + col] = value;
      }
    }
  }

  double _computeStep(
    StdDequantizerParams params,
    bool derived,
    SubbandSyn subband,
    int component,
    int shiftBits,
  ) {
    final steps = params.nStep;
    if (steps == null || steps.isEmpty) {
      throw StateError('Non-reversible quantization requires step sizes');
    }

    double step;
    if (derived) {
      final root = src.getSynSubbandTree(src.getTileIdx(), component);
      final mrl = root.resLvl;
      step = steps[0][0] *
          (1 << (rb[component] + subband.anGainExp + mrl - subband.level));
    } else {
      final resList = steps[subband.resLvl];
      if (resList.length <= subband.sbandIdx) {
        throw StateError('Missing quantization step for subband');
      }
      step = resList[subband.sbandIdx] *
          (1 << (rb[component] + subband.anGainExp));
    }
    return step / (1 << shiftBits);
  }

  void _prepareFloatBlock(DataBlkFloat outBlock, DataBlkInt quantized) {
    outBlock
      ..ulx = quantized.ulx
      ..uly = quantized.uly
      ..w = quantized.w
      ..h = quantized.h
      ..offset = 0
      ..scanw = quantized.w;
    final needed = quantized.w * quantized.h;
    var buffer = outBlock.getDataFloat();
    if (buffer == null || buffer.length < needed) {
      buffer = Float32List(needed);
      outBlock.setData(buffer);
    }
  }
}
