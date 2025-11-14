import 'dart:math' as math;

import 'cos_array.dart';
import 'cos_base.dart';
import 'cos_dictionary.dart';
import 'cos_name.dart';
import 'cos_number.dart';
import 'cos_object.dart';
import 'cos_object_key.dart';
import 'cos_stream.dart';

class COSDocument {
  COSDocument();

  final Map<COSObjectKey, COSObject> _objects = <COSObjectKey, COSObject>{};
  final COSDictionary trailer = COSDictionary();
  final Map<COSObjectKey, int> _xrefTable = <COSObjectKey, int>{};

  bool _closed = false;
  int? _startXref;
  bool _isXRefStream = false;
  bool _hasHybridXRef = false;
  int _highestXRefObjectNumber = 0;
  String _headerVersion = '1.7';

  static final RegExp _versionPattern = RegExp(r'^\d+(?:\.\d+)?$');

  Iterable<COSObject> get objects => _objects.values;

  COSObject? getObject(COSObjectKey key) => _objects[key];

  COSObject? getObjectByNumber(int objectNumber, [int generationNumber = 0]) =>
      getObject(COSObjectKey(objectNumber, generationNumber));

  COSObject getObjectFromPool(COSObjectKey key) {
    return _objects.putIfAbsent(key, () => COSObject.fromKey(key));
  }

  /// Returns the linearization dictionary if the PDF is linearized.
  COSDictionary? getLinearizedDictionary() {
    final entries = _xrefTable.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in entries) {
      final cosObject = _objects[entry.key];
      final COSBase? actual = cosObject?.object;
      if (actual is COSDictionary && actual.getItem(COSName.linearized) != null) {
        return actual;
      }
    }
    for (final cosObject in _objects.values) {
      final COSBase actual = cosObject.object;
      if (actual is COSDictionary && actual.getItem(COSName.linearized) != null) {
        return actual;
      }
    }
    return null;
  }

  List<COSObject> getObjectsByType(COSName type1, [COSName? type2]) {
    final result = <COSObject>[];
    for (final cosObject in _objects.values) {
      final COSBase actual = cosObject.object;
      if (actual is COSDictionary) {
        final COSName? dictType = actual.getCOSName(COSName.type);
        if (dictType == type1 || (type2 != null && dictType == type2)) {
          result.add(cosObject);
        }
      }
    }
    return result;
  }

  List<COSStream> getLinearizationHintStreams() {
    final hints = <COSStream>[];
    for (final cosObject in getObjectsByType(COSName.hints)) {
      final COSBase actual = cosObject.object;
      if (actual is COSStream) {
        hints.add(actual);
      }
    }
    return hints;
  }

  COSStream? getPrimaryLinearizationHintStream() {
    final hints = getLinearizationHintStreams();
    return hints.isNotEmpty ? hints.first : null;
  }

  /// Returns the raw array from the linearization dictionary describing hint offsets.
  List<int>? getLinearizationHintOffsets() {
    final COSDictionary? linearized = getLinearizedDictionary();
    if (linearized == null) {
      return null;
    }
    final COSArray? hintArray = linearized.getCOSArray(COSName.h);
    if (hintArray == null || hintArray.isEmpty) {
      return null;
    }
    final offsets = <int>[];
    for (final COSBase base in hintArray) {
      final COSBase resolved = base is COSObject ? base.object : base;
      if (resolved is COSNumber) {
        offsets.add(resolved.intValue);
      }
    }
    return offsets.isEmpty ? null : offsets;
  }

  void addObject(COSObject object) {
    if (_closed) {
      throw StateError('COSDocument is closed');
    }
    final key = object.key;
    if (key == null) {
      throw StateError('Cannot add a COSObject without an object key');
    }
    _objects[key] = object;
    final objectNumber = key.objectNumber;
    if (objectNumber > _highestXRefObjectNumber) {
      _highestXRefObjectNumber = objectNumber;
    }
    object.markDirty();
  }

  COSObject createObject([COSBase? value]) {
    final nextObjectNumber = math.max(_highestXRefObjectNumber, _objects.length) + 1;
    final obj = COSObject(nextObjectNumber, 0, value);
    addObject(obj);
    value?.markDirty();
    return obj;
  }

  void removeObject(COSObject object) {
    final key = object.key;
    if (key != null) {
      _objects.remove(key);
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _objects.clear();
    trailer.clear();
    _xrefTable.clear();
    _startXref = null;
    _isXRefStream = false;
    _highestXRefObjectNumber = 0;
    _headerVersion = '1.7';
  }

  bool get isClosed => _closed;

  int? get startXref => _startXref;

  set startXref(int? value) => _startXref = value;

  bool get isXRefStream => _isXRefStream;

  set isXRefStream(bool value) => _isXRefStream = value;

  bool get hasHybridXRef => _hasHybridXRef;

  set hasHybridXRef(bool value) => _hasHybridXRef = value;

  void markHybridXRef() {
    _hasHybridXRef = true;
  }

  Map<COSObjectKey, int> get xrefTable => _xrefTable;

  void addXRefTable(Map<COSObjectKey, int> table) {
    _xrefTable.addAll(table);
  }

  int get highestXRefObjectNumber => _highestXRefObjectNumber;

  set highestXRefObjectNumber(int value) {
    if (value < 0) {
      throw ArgumentError.value(
          value, 'value', 'highestXRefObjectNumber cannot be negative');
    }
    _highestXRefObjectNumber = value;
  }

  void setTrailer(COSDictionary dictionary) {
    trailer
      ..clear()
      ..addAll(dictionary);
    trailer.markCleanDeep();
  }

  String get headerVersion => _headerVersion;

  set headerVersion(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'PDF version cannot be empty');
    }
    if (!_versionPattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'value',
        'PDF version must match <major>.<minor>',
      );
    }
    _headerVersion = normalized;
  }

  void markAllClean() {
    for (final object in _objects.values) {
      object.markCleanDeep();
    }
    trailer.markCleanDeep();
  }
}
