import '../../../io/ttf_data_stream.dart';

/// Maps glyph IDs to positioning classes for class-based GPOS lookups.
class ClassDefTable {
  ClassDefTable._(this._glyphToClass, this._maxClass);

  factory ClassDefTable.read(TtfDataStream data, int offset) {
    final saved = data.currentPosition;
    data.seek(offset);
    final format = data.readUnsignedShort();
    switch (format) {
      case 1:
        final table = _readFormat1(data);
        data.seek(saved);
        return table;
      case 2:
        final table = _readFormat2(data);
        data.seek(saved);
        return table;
      default:
        data.seek(saved);
        return ClassDefTable._(const <int, int>{}, 0);
    }
  }

  final Map<int, int> _glyphToClass;
  final int _maxClass;

  /// Returns the class value for [glyphId], falling back to class 0.
  int getClass(int glyphId) => _glyphToClass[glyphId] ?? 0;

  /// Returns the maximum class value defined in the table.
  int get maxClass => _maxClass;

  static ClassDefTable _readFormat1(TtfDataStream data) {
    final startGlyphId = data.readUnsignedShort();
    final glyphCount = data.readUnsignedShort();
    final glyphToClass = <int, int>{};
    var maxClass = 0;
    for (var i = 0; i < glyphCount; i++) {
      final classValue = data.readUnsignedShort();
      final glyphId = startGlyphId + i;
      glyphToClass[glyphId] = classValue;
      if (classValue > maxClass) {
        maxClass = classValue;
      }
    }
    return ClassDefTable._(Map<int, int>.unmodifiable(glyphToClass), maxClass);
  }

  static ClassDefTable _readFormat2(TtfDataStream data) {
    final classRangeCount = data.readUnsignedShort();
    final glyphToClass = <int, int>{};
    var maxClass = 0;
    for (var i = 0; i < classRangeCount; i++) {
      final startGlyphId = data.readUnsignedShort();
      final endGlyphId = data.readUnsignedShort();
      final classValue = data.readUnsignedShort();
      if (classValue > maxClass) {
        maxClass = classValue;
      }
      for (var glyphId = startGlyphId; glyphId <= endGlyphId; glyphId++) {
        glyphToClass[glyphId] = classValue;
      }
    }
    return ClassDefTable._(Map<int, int>.unmodifiable(glyphToClass), maxClass);
  }
}
