import 'dart:math' as math;
import 'dart:typed_data';

import '../../decoder/decoder_specs.dart';
import '../../image/data_blk.dart';
import '../../image/data_blk_float.dart';
import '../../image/data_blk_int.dart';
import '../../util/decoder_instrumentation.dart';
import '../../util/int32_utils.dart';
import '../../wavelet/synthesis/subband_syn.dart';
import '../guard_bits_spec.dart';
import '../quant_step_size_spec.dart';
import '../quant_type_spec.dart';
import 'cblk_quant_data_src_dec.dart';
import 'dequantizer.dart';
import 'std_dequantizer_params.dart';

/// Scalar dead-zone dequantizer mirroring JJ2000's implementation.
class StdDequantizer extends Dequantizer {
  static const String _logSource = 'StdDequantizer';
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
  static int _dequantDebug = 40;
  static final Set<String> _floatPreviewKeys = <String>{};
  static final Set<String> _rawPreviewKeys = <String>{};
  static const int _floatPreviewLimit = 32;
  static const int _blockStatsLimit = 2;
  static final Map<String, int> _floatBlockStatsCounts = <String, int>{};
  static final Map<String, int> _intBlockStatsCounts = <String, int>{};
  static const int _shiftLogLimit = 4;
  static final Map<String, int> _shiftLogCounts = <String, int>{};
  static const int _signMask = 0x80000000;
  static const int _magnitudeMask = 0x7fffffff;

  static bool _isInstrumentationEnabled() => DecoderInstrumentation.isEnabled();

  static void _log(String message) {
    if (_isInstrumentationEnabled()) {
      DecoderInstrumentation.log(_logSource, message);
    }
  }

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


    _logIntBlockStats(block, subband, component);
    final shiftBits = 31 - subband.magBits;
    _logShiftInfo(component, subband, shiftBits);

    if (_dequantDebug > 0 && _isInstrumentationEnabled()) {
      _dequantDebug--;
      final header =
          'StdDequantizer: comp=$component res=${subband.resLvl} band=${subband.sbandIdx} '
          'magBits=${subband.magBits} shift=$shiftBits reversible=$reversible len=${data.length}';
      _log(header);
      final sampleCount = math.min(4, data.length);
      final preview = <int>[];
      for (var idx = 0; idx < sampleCount; idx++) {
        preview.add(data[idx]);
      }
      _log('StdDequantizer raw sample preview: ${preview.join(', ')}');
    }

    if (reversible) {
      for (var i = data.length - 1; i >= 0; i--) {
        final temp = Int32Utils.mask32(data[i]);
        final magnitude = temp & _magnitudeMask;
        if ((temp & _signMask) == 0) {
          data[i] = magnitude >> shiftBits;
        } else {
          data[i] = -(magnitude >> shiftBits);
        }
      }
      return;
    }

    final step = _computeStep(params, derived, subband, component, shiftBits);
    for (var i = data.length - 1; i >= 0; i--) {
      final temp = Int32Utils.mask32(data[i]);
      final magnitude = temp & _magnitudeMask;
      final value = (temp & _signMask) == 0
          ? magnitude * step
          : -magnitude * step;
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

    final rawKey = 'raw-c=$component-r=${subband.resLvl}-b=${subband.sbandIdx}';
    if (_isInstrumentationEnabled() &&
        _rawPreviewKeys.length < _floatPreviewLimit &&
        _rawPreviewKeys.add(rawKey)) {
      final preview = <int>[];
      for (var idx = 0; idx < math.min(4, quantized.w * quantized.h); idx++) {
        preview.add(inData[idx]);
      }
      _log('StdDequantizer raw coeffs [unique]: comp=$component '
          'res=${subband.resLvl} band=${subband.sbandIdx} values=${preview.join(', ')}');
    }

    final shiftBits = 31 - subband.magBits;
    _logShiftInfo(component, subband, shiftBits);
    final step = _computeStep(
      params,
      derived,
      subband,
      component,
      shiftBits,
    );

    final width = quantized.w;
    final height = quantized.h;
    final inOffset = quantized.offset;
    final inScanw = quantized.scanw;

    if (_dequantDebug > 0 && _isInstrumentationEnabled()) {
      final preview = <double>[];
      for (var idx = 0; idx < math.min(4, width * height); idx++) {
        final temp = Int32Utils.mask32(inData[idx]);
        final magnitude = temp & _magnitudeMask;
        final double value = (temp & _signMask) == 0
            ? magnitude * step
            : -magnitude * step;
        preview.add(value);
      }
      _log('StdDequantizer float preview: comp=$component res=${subband.resLvl} '
          'band=${subband.sbandIdx} values=${preview.map((v) => v.toStringAsFixed(6)).join(', ')}');
      _dequantDebug--;
    } else if (_isInstrumentationEnabled() &&
        _floatPreviewKeys.length < _floatPreviewLimit) {
      final key = 'c=$component-r=${subband.resLvl}-b=${subband.sbandIdx}';
      if (_floatPreviewKeys.add(key)) {
        final preview = <double>[];
        for (var idx = 0; idx < math.min(4, width * height); idx++) {
          final temp = Int32Utils.mask32(inData[idx]);
          final magnitude = temp & _magnitudeMask;
          final double value = (temp & _signMask) == 0
              ? magnitude * step
              : -magnitude * step;
          preview.add(value);
        }
        _log('StdDequantizer float preview [unique]: comp=$component res=${subband.resLvl} '
            'band=${subband.sbandIdx} values=${preview.map((v) => v.toStringAsFixed(6)).join(', ')}');
      }
    }

    for (var row = 0; row < height; row++) {
      final inBase = inOffset + row * inScanw;
      final outBase = row * width;
      for (var col = 0; col < width; col++) {
        final temp = Int32Utils.mask32(inData[inBase + col]);
        final magnitude = temp & _magnitudeMask;
        final double value = (temp & _signMask) == 0
            ? magnitude * step
            : -magnitude * step;
        outData[outBase + col] = value;
      }
    }

    _logFloatBlockStats(outBlock, subband, component);
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

  void _logFloatBlockStats(
    DataBlkFloat block,
    SubbandSyn subband,
    int component,
  ) {
    if (!_isInstrumentationEnabled() || block.w == 0 || block.h == 0) {
      return;
    }
    final data = block.getDataFloat();
    if (data == null) {
      return;
    }
    final key = 'float-c$component-r${subband.resLvl}-b${subband.sbandIdx}';
    final count = _floatBlockStatsCounts[key] ?? 0;
    if (count >= _blockStatsLimit) {
      return;
    }
    _floatBlockStatsCounts[key] = count + 1;
    final summary = _summarizeFloatBlock(
      data,
      block.w,
      block.h,
      block.offset,
      block.scanw,
    );
    _log(
      'StdDequantizer float stats: comp=$component res=${subband.resLvl} '
      'band=${subband.sbandIdx} block=${block.w}x${block.h} '
      'min=${summary.minLabel} max=${summary.maxLabel} preview=${summary.preview}',
    );
  }

  void _logIntBlockStats(
    DataBlkInt block,
    SubbandSyn subband,
    int component,
  ) {
    if (!_isInstrumentationEnabled() || block.w == 0 || block.h == 0) {
      return;
    }
    final data = block.getDataInt();
    if (data == null) {
      return;
    }
    final key = 'int-c$component-r${subband.resLvl}-b${subband.sbandIdx}';
    final count = _intBlockStatsCounts[key] ?? 0;
    if (count >= _blockStatsLimit) {
      return;
    }
    _intBlockStatsCounts[key] = count + 1;
    final summary = _summarizeIntBlock(
      data,
      block.w,
      block.h,
      block.offset,
      block.scanw,
    );
    _log(
      'StdDequantizer int stats: comp=$component res=${subband.resLvl} '
      'band=${subband.sbandIdx} block=${block.w}x${block.h} '
      'min=${summary.minLabel} max=${summary.maxLabel} preview=${summary.preview}',
    );
  }

  _BlockStats _summarizeFloatBlock(
    Float32List data,
    int width,
    int height,
    int offset,
    int scanw,
  ) {
    var minVal = data[offset];
    var maxVal = data[offset];
    final previewCount = math.min(width, 8);
    final preview = <String>[];
    var rowOffset = offset;
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        final sample = data[rowOffset + col];
        if (sample < minVal) {
          minVal = sample;
        }
        if (sample > maxVal) {
          maxVal = sample;
        }
        if (row == 0 && col < previewCount) {
          preview.add(sample.toStringAsFixed(4));
        }
      }
      rowOffset += scanw;
    }
    return _BlockStats(
      minVal.toStringAsFixed(6),
      maxVal.toStringAsFixed(6),
      '[${preview.join(', ')}]',
    );
  }

  _BlockStats _summarizeIntBlock(
    List<int> data,
    int width,
    int height,
    int offset,
    int scanw,
  ) {
    var minVal = data[offset];
    var maxVal = data[offset];
    final previewCount = math.min(width, 8);
    final preview = <String>[];
    var rowOffset = offset;
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        final sample = data[rowOffset + col];
        if (sample < minVal) {
          minVal = sample;
        }
        if (sample > maxVal) {
          maxVal = sample;
        }
        if (row == 0 && col < previewCount) {
          preview.add(sample.toString());
        }
      }
      rowOffset += scanw;
    }
    return _BlockStats(
      minVal.toString(),
      maxVal.toString(),
      '[${preview.join(', ')}]',
    );
  }
  void _logShiftInfo(int component, SubbandSyn subband, int shiftBits) {
    if (!_isInstrumentationEnabled()) {
      return;
    }
    final key = 'shift-c$component-r${subband.resLvl}-b${subband.sbandIdx}';
    final count = _shiftLogCounts[key] ?? 0;
    if (count >= _shiftLogLimit) {
      return;
    }
    _shiftLogCounts[key] = count + 1;
    final gain = subband.anGainExp;
    final magBits = subband.magBits;
    final rangeBits = component < rb.length ? rb[component] : -1;
    _log(
      'StdDequantizer shift: comp=$component res=${subband.resLvl} '
      'band=${subband.sbandIdx} magBits=$magBits shiftBits=$shiftBits '
      'rb=$rangeBits anGainExp=$gain',
    );
  }
}

class _BlockStats {
  const _BlockStats(this.minLabel, this.maxLabel, this.preview);

  final String minLabel;
  final String maxLabel;
  final String preview;
}
