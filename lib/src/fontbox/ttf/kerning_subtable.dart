import 'package:logging/logging.dart';

import '../io/ttf_data_stream.dart';

/// Parser for a single TrueType 'kern' subtable.
class KerningSubtable {
  KerningSubtable();

  static final Logger _log = Logger('fontbox.KerningSubtable');

  static const int _coverageHorizontal = 0x0001;
  static const int _coverageMinimums = 0x0002;
  static const int _coverageCrossStream = 0x0004;
  static const int _coverageFormat = 0xFF00;

  static const int _coverageHorizontalShift = 0;
  static const int _coverageMinimumsShift = 1;
  static const int _coverageCrossStreamShift = 2;
  static const int _coverageFormatShift = 8;

  bool _horizontal = false;
  bool _minimums = false;
  bool _crossStream = false;
  _PairData? _pairs;

  /// Reads the kerning subtable from [data].
  void read(TtfDataStream data, int version) {
    if (version == 0) {
      _readSubtable0(data);
    } else if (version == 1) {
      _readSubtable1(data);
    } else {
      throw StateError('Unsupported kerning subtable version $version');
    }
  }

  /// Returns true when this kerning subtable applies to horizontal layout.
  bool isHorizontalKerning([bool cross = false]) {
    if (!_horizontal || _minimums) {
      return false;
    }
    return cross ? _crossStream : !_crossStream;
  }

  /// Computes kerning adjustments for a glyph sequence.
  List<int> getKerning(List<int> glyphs) {
    final pairData = _pairs;
    if (pairData == null) {
      _log.warning(
        'No kerning subtable data available due to an unsupported kerning subtable version',
      );
      return List<int>.filled(glyphs.length, 0, growable: false);
    }

    final adjustments = List<int>.filled(glyphs.length, 0, growable: false);
    for (var i = 0; i < glyphs.length; ++i) {
      final left = glyphs[i];
      var right = -1;
      for (var k = i + 1; k < glyphs.length; ++k) {
        final glyph = glyphs[k];
        if (glyph >= 0) {
          right = glyph;
          break;
        }
      }
      adjustments[i] = pairData.getKerning(left, right);
    }
    return adjustments;
  }

  /// Kerning adjustment for a single glyph pair.
  int getPairKerning(int left, int right) {
    final pairData = _pairs;
    if (pairData == null) {
      _log.warning(
        'No kerning subtable data available due to an unsupported kerning subtable version',
      );
      return 0;
    }
    return pairData.getKerning(left, right);
  }

  void _readSubtable0(TtfDataStream data) {
    final version = data.readUnsignedShort();
    if (version != 0) {
      _log.info('Unsupported kerning sub-table version: $version');
      return;
    }
    final length = data.readUnsignedShort();
    if (length < 6) {
      _log.warning(
          'Kerning sub-table too short, got $length bytes, expect 6 or more.');
      return;
    }
    final coverage = data.readUnsignedShort();
    if (_isBitsSet(coverage, _coverageHorizontal, _coverageHorizontalShift)) {
      _horizontal = true;
    }
    if (_isBitsSet(coverage, _coverageMinimums, _coverageMinimumsShift)) {
      _minimums = true;
    }
    if (_isBitsSet(coverage, _coverageCrossStream, _coverageCrossStreamShift)) {
      _crossStream = true;
    }
    final format = _getBits(coverage, _coverageFormat, _coverageFormatShift);
    switch (format) {
      case 0:
        _readSubtable0Format0(data);
        break;
      case 2:
        _readSubtable0Format2(data);
        break;
      default:
        _log.fine(
            'Skipped kerning subtable due to an unsupported kerning subtable version: $format');
        break;
    }
  }

  void _readSubtable0Format0(TtfDataStream data) {
    final pairData = _PairData0Format0();
    pairData.read(data);
    _pairs = pairData;
  }

  void _readSubtable0Format2(TtfDataStream data) {
    _log.info('Kerning subtable format 2 not yet supported.');
  }

  void _readSubtable1(TtfDataStream data) {
    _log.info('Kerning subtable format 1 not yet supported.');
  }

  static bool _isBitsSet(int value, int mask, int shift) =>
      _getBits(value, mask, shift) != 0;

  static int _getBits(int value, int mask, int shift) =>
      (value & mask) >> shift;
}

abstract class _PairData {
  void read(TtfDataStream data);
  int getKerning(int left, int right);
}

class _PairData0Format0 implements _PairData {
  late final List<List<int>> _pairs;

  @override
  void read(TtfDataStream data) {
    final numPairs = data.readUnsignedShort();
    data.readUnsignedShort(); // searchRange, unused
    data.readUnsignedShort(); // entrySelector
    data.readUnsignedShort(); // rangeShift
    _pairs = List<List<int>>.generate(numPairs, (_) => List<int>.filled(3, 0));
    for (var i = 0; i < numPairs; ++i) {
      _pairs[i][0] = data.readUnsignedShort();
      _pairs[i][1] = data.readUnsignedShort();
      _pairs[i][2] = data.readSignedShort();
    }
  }

  @override
  int getKerning(int left, int right) {
    if (_pairs.isEmpty) {
      return 0;
    }
    var low = 0;
    var high = _pairs.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final entry = _pairs[mid];
      final cmpLeft = left - entry[0];
      if (cmpLeft == 0) {
        final cmpRight = right - entry[1];
        if (cmpRight == 0) {
          return entry[2];
        }
        if (cmpRight < 0) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      } else if (cmpLeft < 0) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return 0;
  }
}
