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
  static const int _coverageV1Vertical = 0x8000;
  static const int _coverageV1CrossStream = 0x4000;
  static const int _coverageV1FormatMask = 0x00FF;

  bool _horizontal = false;
  bool _minimums = false;
  bool _crossStream = false;
  _KerningEngine? _kerning;

  /// Reads the kerning subtable from [data].
  void read(TtfDataStream data, int version) {
    _horizontal = false;
    _minimums = false;
    _crossStream = false;
    _kerning = null;
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
    final engine = _kerning;
    if (engine == null) {
      _log.warning(
        'No kerning subtable data available due to an unsupported kerning subtable version',
      );
      return List<int>.filled(glyphs.length, 0, growable: false);
    }
    return engine.compute(glyphs);
  }

  /// Kerning adjustment for a single glyph pair.
  int getPairKerning(int left, int right) {
    final engine = _kerning;
    if (engine == null) {
      _log.warning(
        'No kerning subtable data available due to an unsupported kerning subtable version',
      );
      return 0;
    }
    return engine.pairKerning(left, right);
  }

  void _readSubtable0(TtfDataStream data) {
    final version = data.readUnsignedShort();
    final length = data.readUnsignedShort();
    final coverage = data.readUnsignedShort();
    final subtableStart = data.currentPosition - 6;
    final subtableEnd = subtableStart + length;

    if (version != 0) {
      _log.info('Unsupported kerning sub-table version: $version');
      _seekTo(data, subtableEnd);
      return;
    }

    if (length < 6) {
      _log.warning(
        'Kerning sub-table too short, got $length bytes, expect 6 or more.',
      );
      _seekTo(data, subtableEnd);
      return;
    }

    _applyLegacyCoverage(coverage);

    final format = _getBits(coverage, _coverageFormat, _coverageFormatShift);
    switch (format) {
      case 0:
        _readSubtable0Format0(data);
        break;
      case 1:
        _readContextualSubtable(data, subtableStart, length);
        break;
      case 2:
        _readSubtable0Format2(data, subtableStart, length);
        break;
      default:
        _log.fine(
          'Skipped kerning subtable due to an unsupported kerning subtable format: $format',
        );
        break;
    }

    _seekTo(data, subtableEnd);
  }

  void _readSubtable0Format0(TtfDataStream data) {
    final pairData = _PairData0Format0();
    pairData.read(data);
    _kerning = _PairKerningEngine(pairData);
  }

  void _readSubtable0Format2(
    TtfDataStream data,
    int subtableStart,
    int length,
  ) {
    final subtableEnd = subtableStart + length;
    final rowWidth = data.readUnsignedShort();
    final leftClassOffset = data.readUnsignedShort();
    final rightClassOffset = data.readUnsignedShort();
    final arrayOffset = data.readUnsignedShort();

    if (rowWidth <= 0) {
      _log.warning(
          'Kerning sub-table format 2 with invalid row width: $rowWidth');
      return;
    }

    if (leftClassOffset != 0 &&
        !_isValidOffset(subtableStart, subtableEnd, leftClassOffset, 4)) {
      _log.warning(
        'Kerning sub-table format 2 with invalid left class offset: $leftClassOffset',
      );
      return;
    }
    if (rightClassOffset != 0 &&
        !_isValidOffset(subtableStart, subtableEnd, rightClassOffset, 4)) {
      _log.warning(
        'Kerning sub-table format 2 with invalid right class offset: $rightClassOffset',
      );
      return;
    }
    if (!_isValidOffset(subtableStart, subtableEnd, arrayOffset, 2)) {
      _log.warning(
        'Kerning sub-table format 2 with invalid array offset: $arrayOffset',
      );
      return;
    }

    final leftClasses = _readClassTable(data, subtableStart, leftClassOffset);
    final rightClasses = _readClassTable(data, subtableStart, rightClassOffset);

    final leftClassCount = leftClasses.maxClass + 1;
    final rightClassCount = rowWidth ~/ 2;
    if (leftClassCount <= 0 || rightClassCount <= 0) {
      _log.warning(
        'Kerning sub-table format 2 with invalid class counts: left=$leftClassCount right=$rightClassCount',
      );
      return;
    }

    final kerning = List<List<int>>.generate(
      leftClassCount,
      (_) => List<int>.filled(rightClassCount, 0, growable: false),
      growable: false,
    );

    final saved = data.currentPosition;
    try {
      data.seek(subtableStart + arrayOffset);
      final valuesPerRow = rowWidth ~/ 2;
      for (var left = 0; left < leftClassCount; left++) {
        for (var right = 0; right < valuesPerRow; right++) {
          kerning[left][right] = data.readSignedShort();
        }
      }
    } finally {
      data.seek(saved);
    }

    _kerning = _PairKerningEngine(
      _PairData0Format2(
        leftClasses.mapping,
        rightClasses.mapping,
        kerning,
      ),
    );
  }

  void _readContextualSubtable(
    TtfDataStream data,
    int subtableStart,
    int length,
  ) {
    final subtableEnd = subtableStart + length;
    final stateTableStart = data.currentPosition;

    if (stateTableStart + 10 > subtableEnd) {
      _log.warning('Kerning sub-table format 1 header truncated.');
      return;
    }

    final stateSize = data.readUnsignedShort();
    final classTableOffset = data.readUnsignedShort();
    final stateArrayOffset = data.readUnsignedShort();
    final entryTableOffset = data.readUnsignedShort();
    final valueTableOffset = data.readUnsignedShort();

    if (stateSize <= 0) {
      _log.warning(
          'Kerning sub-table format 1 with invalid state size: $stateSize');
      return;
    }

    final stateArrayStart = stateTableStart + stateArrayOffset;
    final entryTableStart = stateTableStart + entryTableOffset;
    final valueTableStart = subtableStart + valueTableOffset;

    if (classTableOffset != 0 &&
        !_isValidOffset(stateTableStart, subtableEnd, classTableOffset, 4)) {
      _log.warning(
        'Kerning sub-table format 1 with invalid class table offset: $classTableOffset',
      );
      return;
    }
    if (!_isValidOffset(
        stateTableStart, subtableEnd, stateArrayOffset, stateSize)) {
      _log.warning(
        'Kerning sub-table format 1 with invalid state array offset: $stateArrayOffset',
      );
      return;
    }
    if (!_isValidOffset(stateTableStart, subtableEnd, entryTableOffset, 4)) {
      _log.warning(
        'Kerning sub-table format 1 with invalid entry table offset: $entryTableOffset',
      );
      return;
    }
    if (!_isValidOffset(subtableStart, subtableEnd, valueTableOffset, 2)) {
      _log.warning(
        'Kerning sub-table format 1 with invalid value table offset: $valueTableOffset',
      );
      return;
    }

    final stateArrayLength = entryTableStart - stateArrayStart;
    if (stateArrayLength <= 0) {
      _log.warning('Kerning sub-table format 1 missing state array data.');
      return;
    }

    final stateCount = stateArrayLength ~/ stateSize;
    if (stateCount <= 0) {
      _log.warning('Kerning sub-table format 1 without states.');
      return;
    }

    final classMapping = _readContextualClassTable(
      data,
      stateTableStart,
      classTableOffset,
      subtableEnd,
    );
    final stateArray = _readStateArray(
      data,
      stateArrayStart,
      stateSize,
      stateCount,
      entryTableStart,
    );
    if (stateArray.isEmpty) {
      _log.warning('Kerning sub-table format 1 state array malformed.');
      return;
    }

    final entryTableLength = valueTableStart - entryTableStart;
    if (entryTableLength <= 0 || entryTableLength % 4 != 0) {
      _log.warning('Kerning sub-table format 1 entry table malformed.');
      return;
    }

    final entryCount = entryTableLength ~/ 4;
    final entries = _readStateEntries(
      data,
      entryTableStart,
      entryCount,
      stateArrayOffset,
      stateSize,
      stateCount,
    );
    if (entries.isEmpty) {
      _log.warning('Kerning sub-table format 1 without entries.');
      return;
    }

    if (_crossStream) {
      _log.info(
          'Kerning sub-table format 1 cross-stream kerning is not supported.');
      return;
    }

    final valueRecords = <int, List<int>>{};
    for (final entry in entries) {
      final offset = entry.valueOffset;
      if (offset == 0 || valueRecords.containsKey(offset)) {
        continue;
      }
      if (!_isValidOffset(subtableStart, subtableEnd, offset, 2)) {
        _log.warning(
          'Kerning sub-table format 1 references invalid value list offset: $offset',
        );
        continue;
      }
      valueRecords[offset] = _readValueList(
        data,
        subtableStart,
        subtableEnd,
        offset,
      );
    }

    _kerning = _ContextualKerningEngine(
      classMapping: classMapping,
      stateArray: stateArray,
      entries: entries,
      valueRecords: valueRecords,
      stateSize: stateSize,
      stateCount: stateCount,
    );
  }

  Map<int, int> _readContextualClassTable(
    TtfDataStream data,
    int stateTableStart,
    int classTableOffset,
    int subtableEnd,
  ) {
    if (classTableOffset == 0) {
      return const <int, int>{};
    }
    final saved = data.currentPosition;
    try {
      data.seek(stateTableStart + classTableOffset);
      final firstGlyph = data.readUnsignedShort();
      final glyphCount = data.readUnsignedShort();
      final mapping = <int, int>{};
      for (var i = 0; i < glyphCount; i++) {
        if (data.currentPosition >= subtableEnd) {
          break;
        }
        final classValue = data.readUnsignedByte();
        mapping[firstGlyph + i] = classValue;
      }
      return mapping;
    } finally {
      data.seek(saved);
    }
  }

  List<List<int>> _readStateArray(
    TtfDataStream data,
    int stateArrayStart,
    int stateSize,
    int stateCount,
    int entryTableStart,
  ) {
    final saved = data.currentPosition;
    try {
      data.seek(stateArrayStart);
      final states = List<List<int>>.generate(
        stateCount,
        (_) => List<int>.filled(stateSize, 0, growable: false),
        growable: false,
      );
      for (var state = 0; state < stateCount; state++) {
        for (var cls = 0; cls < stateSize; cls++) {
          if (data.currentPosition >= entryTableStart) {
            return const <List<int>>[];
          }
          states[state][cls] = data.readUnsignedByte();
        }
      }
      return states;
    } finally {
      data.seek(saved);
    }
  }

  List<_StateEntry> _readStateEntries(
    TtfDataStream data,
    int entryTableStart,
    int entryCount,
    int stateArrayOffset,
    int stateSize,
    int stateCount,
  ) {
    final saved = data.currentPosition;
    try {
      data.seek(entryTableStart);
      final entries = <_StateEntry>[];
      for (var i = 0; i < entryCount; i++) {
        final newStateOffset = data.readUnsignedShort();
        final flags = data.readUnsignedShort();
        entries.add(
          _StateEntry(
            newStateIndex: _resolveStateIndex(
              newStateOffset,
              stateArrayOffset,
              stateSize,
              stateCount,
            ),
            push: (flags & 0x8000) != 0,
            dontAdvance: (flags & 0x4000) != 0,
            valueOffset: flags & 0x3FFF,
          ),
        );
      }
      return entries;
    } finally {
      data.seek(saved);
    }
  }

  List<int> _readValueList(
    TtfDataStream data,
    int subtableStart,
    int subtableEnd,
    int offset,
  ) {
    final saved = data.currentPosition;
    final values = <int>[];
    try {
      data.seek(subtableStart + offset);
      while (data.currentPosition + 2 <= subtableEnd && values.length < 32) {
        final value = data.readSignedShort();
        values.add(value);
        if ((value & 1) != 0) {
          break;
        }
      }
    } finally {
      data.seek(saved);
    }
    return values;
  }

  void _applyLegacyCoverage(int coverage) {
    if (_isBitsSet(coverage, _coverageHorizontal, _coverageHorizontalShift)) {
      _horizontal = true;
    }
    if (_isBitsSet(coverage, _coverageMinimums, _coverageMinimumsShift)) {
      _minimums = true;
    }
    if (_isBitsSet(coverage, _coverageCrossStream, _coverageCrossStreamShift)) {
      _crossStream = true;
    }
  }

  void _applyModernCoverage(int coverage) {
    _horizontal = (coverage & _coverageV1Vertical) == 0;
    _minimums = false;
    _crossStream = (coverage & _coverageV1CrossStream) != 0;
  }

  void _seekTo(TtfDataStream data, int position) {
    if (position < 0) {
      return;
    }
    data.seek(position);
  }

  bool _isValidOffset(
    int base,
    int limit,
    int offset,
    int minimumLength,
  ) {
    if (offset < 0) {
      return false;
    }
    final start = base + offset;
    if (start < base || start > limit) {
      return false;
    }
    return start + minimumLength <= limit;
  }

  int _resolveStateIndex(
    int offset,
    int stateArrayOffset,
    int stateSize,
    int stateCount,
  ) {
    if (stateCount <= 0 || stateSize <= 0) {
      return 0;
    }
    final relative = offset - stateArrayOffset;
    if (relative < 0) {
      return 0;
    }
    final index = relative ~/ stateSize;
    if (index < 0 || index >= stateCount) {
      return 0;
    }
    return index;
  }

  void _readSubtable1(TtfDataStream data) {
    final length = data.readUnsignedInt();
    final coverage = data.readUnsignedShort();
    data.readUnsignedShort(); // tuple index, currently unused
    final subtableStart = data.currentPosition - 8;
    final subtableEnd = subtableStart + length;

    if (length < 8) {
      _log.warning(
        "Kerning sub-table length too short for version 1: $length bytes.",
      );
      _seekTo(data, subtableEnd);
      return;
    }

    _applyModernCoverage(coverage);

    final format = coverage & _coverageV1FormatMask;
    switch (format) {
      case 1:
        _readContextualSubtable(data, subtableStart, length);
        break;
      default:
        _log.fine(
          'Skipped kerning subtable due to an unsupported kerning subtable format: $format',
        );
        break;
    }

    _seekTo(data, subtableEnd);
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

class _PairData0Format2 implements _PairData {
  _PairData0Format2(this._leftClasses, this._rightClasses, this._matrix);

  final Map<int, int> _leftClasses;
  final Map<int, int> _rightClasses;
  final List<List<int>> _matrix;

  @override
  void read(TtfDataStream data) {}

  @override
  int getKerning(int left, int right) {
    final leftClass = _leftClasses[left] ?? 0;
    final rightClass = _rightClasses[right] ?? 0;
    if (leftClass < 0 || leftClass >= _matrix.length) {
      return 0;
    }
    final row = _matrix[leftClass];
    if (rightClass < 0 || rightClass >= row.length) {
      return 0;
    }
    return row[rightClass];
  }
}

_ClassTableData _readClassTable(
  TtfDataStream data,
  int subtableStart,
  int offset,
) {
  if (offset == 0) {
    return const _ClassTableData(<int, int>{}, 0);
  }
  final saved = data.currentPosition;
  try {
    data.seek(subtableStart + offset);
    final firstGlyph = data.readUnsignedShort();
    final glyphCount = data.readUnsignedShort();
    final mapping = <int, int>{};
    var maxClass = 0;
    for (var i = 0; i < glyphCount; i++) {
      final classValue = data.readUnsignedShort();
      mapping[firstGlyph + i] = classValue;
      if (classValue > maxClass) {
        maxClass = classValue;
      }
    }
    return _ClassTableData(mapping, maxClass);
  } finally {
    data.seek(saved);
  }
}

class _ClassTableData {
  const _ClassTableData(this.mapping, this.maxClass);

  final Map<int, int> mapping;
  final int maxClass;
}

abstract class _KerningEngine {
  List<int> compute(List<int> glyphs);
  int pairKerning(int left, int right);
}

class _PairKerningEngine implements _KerningEngine {
  _PairKerningEngine(this._pairData);

  final _PairData _pairData;

  @override
  List<int> compute(List<int> glyphs) {
    if (glyphs.isEmpty) {
      return const <int>[];
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
      adjustments[i] = _pairData.getKerning(left, right);
    }
    return adjustments;
  }

  @override
  int pairKerning(int left, int right) => _pairData.getKerning(left, right);
}

class _StateEntry {
  const _StateEntry({
    required this.newStateIndex,
    required this.push,
    required this.dontAdvance,
    required this.valueOffset,
  });

  final int newStateIndex;
  final bool push;
  final bool dontAdvance;
  final int valueOffset;
}

class _ContextualKerningEngine implements _KerningEngine {
  _ContextualKerningEngine({
    required this.classMapping,
    required this.stateArray,
    required this.entries,
    required this.valueRecords,
    required this.stateSize,
    required this.stateCount,
  });

  final Map<int, int> classMapping;
  final List<List<int>> stateArray;
  final List<_StateEntry> entries;
  final Map<int, List<int>> valueRecords;
  final int stateSize;
  final int stateCount;

  static const int _maxStackSize = 8;

  @override
  List<int> compute(List<int> glyphs) {
    if (glyphs.isEmpty) {
      return const <int>[];
    }
    final adjustments = List<int>.filled(glyphs.length, 0, growable: false);
    if (stateArray.isEmpty || entries.isEmpty) {
      return adjustments;
    }

    final stack = <int>[];
    var state = 0;
    var index = 0;
    var iterations = 0;
    while (true) {
      final atEnd = index >= glyphs.length;
      final glyphId = atEnd ? -1 : glyphs[index];
      final glyphClass = _classForGlyph(glyphId, atEnd);
      final entryIndex = _entryIndex(state, glyphClass);

      _StateEntry? entry;
      if (entryIndex >= 0 && entryIndex < entries.length) {
        entry = entries[entryIndex];

        if (entry.push && !atEnd && stack.length < _maxStackSize) {
          stack.add(index);
        }

        if (entry.valueOffset != 0) {
          final values = valueRecords[entry.valueOffset];
          if (values != null) {
            for (final value in values) {
              if (stack.isEmpty) {
                break;
              }
              final position = stack.removeLast();
              if (position >= 0 && position < adjustments.length) {
                adjustments[position] += value;
              }
            }
          }
        }

        state = entry.newStateIndex;
      } else {
        state = 0;
      }

      final advance = entry == null ? true : !entry.dontAdvance;
      if (advance) {
        if (atEnd) {
          break;
        }
        index += 1;
      } else if (atEnd) {
        break;
      }

      iterations++;
      if (iterations > glyphs.length + 16) {
        break;
      }
    }
    return adjustments;
  }

  @override
  int pairKerning(int left, int right) {
    final adjustments = compute(<int>[left, right]);
    return adjustments.isEmpty ? 0 : adjustments[0];
  }

  int _classForGlyph(int glyphId, bool atEnd) {
    if (atEnd) {
      return 0;
    }
    if (glyphId < 0) {
      return stateSize > 2 ? 2 : 1;
    }
    final value = classMapping[glyphId];
    if (value == null) {
      return stateSize > 1 ? 1 : 0;
    }
    if (value < 0) {
      return 0;
    }
    if (value >= stateSize) {
      return stateSize - 1;
    }
    return value;
  }

  int _entryIndex(int state, int glyphClass) {
    if (state < 0 || state >= stateArray.length) {
      return 0;
    }
    final row = stateArray[state];
    var cls = glyphClass;
    if (cls < 0) {
      cls = 0;
    } else if (cls >= row.length) {
      cls = row.length - 1;
    }
    return row[cls];
  }
}
