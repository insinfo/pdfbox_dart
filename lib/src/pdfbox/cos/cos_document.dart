import 'dart:math' as math;

import 'cos_base.dart';
import 'cos_dictionary.dart';
import 'cos_object.dart';
import 'cos_object_key.dart';

class COSDocument {
  COSDocument();

  final Map<COSObjectKey, COSObject> _objects = <COSObjectKey, COSObject>{};
  final COSDictionary trailer = COSDictionary();
  final Map<COSObjectKey, int> _xrefTable = <COSObjectKey, int>{};

  bool _closed = false;
  int? _startXref;
  bool _isXRefStream = false;
  int _highestXRefObjectNumber = 0;

  Iterable<COSObject> get objects => _objects.values;

  COSObject? getObject(COSObjectKey key) => _objects[key];

  COSObject? getObjectByNumber(int objectNumber, [int generationNumber = 0]) =>
      getObject(COSObjectKey(objectNumber, generationNumber));

  COSObject getObjectFromPool(COSObjectKey key) {
    return _objects.putIfAbsent(key, () => COSObject.fromKey(key));
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
  }

  bool get isClosed => _closed;

  int? get startXref => _startXref;

  set startXref(int? value) => _startXref = value;

  bool get isXRefStream => _isXRefStream;

  set isXRefStream(bool value) => _isXRefStream = value;

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

  void markAllClean() {
    for (final object in _objects.values) {
      object.markCleanDeep();
    }
    trailer.markCleanDeep();
  }
}
