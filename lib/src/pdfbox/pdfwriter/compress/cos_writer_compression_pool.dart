import 'dart:collection';

import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_document.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_object_key.dart';
import '../../cos/cos_stream.dart';
import '../../pdmodel/pd_document.dart';
import 'compress_parameters.dart';
import 'cos_object_pool.dart';
import 'cos_writer_object_stream.dart';

/// Pools COS objects and groups them into top-level and object stream entries.
class COSWriterCompressionPool {
  COSWriterCompressionPool(PDDocument document, CompressParameters? parameters)
      : _document = document,
        _parameters = parameters ?? const CompressParameters(),
        _objectPool = COSObjectPool(
          document.cosDocument.highestXRefObjectNumber,
        ) {
    final COSDocument cosDocument = document.cosDocument;
    final COSDictionary trailer = cosDocument.trailer;
    _addStructure(trailer.getItem(COSName.root));
    _addStructure(trailer.getItem(COSName.info));

    _objectStreamObjects.sort(_compareKeys);
    _topLevelObjects.sort(_compareKeys);
  }

  static const double minimumSupportedVersion = 1.6;

  final PDDocument _document;
  final CompressParameters _parameters;
  final COSObjectPool _objectPool;

  final List<COSObjectKey> _topLevelObjects = <COSObjectKey>[];
  final List<COSObjectKey> _objectStreamObjects = <COSObjectKey>[];
  final Set<COSBase> _allDirectObjects = HashSet<COSBase>(
    equals: identical,
    hashCode: identityHashCode,
  );

  List<COSObjectKey> getTopLevelObjects() => List<COSObjectKey>.unmodifiable(_topLevelObjects);

  List<COSObjectKey> getObjectStreamObjects() =>
      List<COSObjectKey>.unmodifiable(_objectStreamObjects);

  bool contains(COSBase object) => _objectPool.containsObject(object);

  COSObjectKey? getKey(COSBase object) => _objectPool.getKey(object);

  COSBase? getObject(COSObjectKey key) => _objectPool.getObject(key);

  int get highestXRefObjectNumber => _objectPool.highestXRefObjectNumber;

  List<COSWriterObjectStream> createObjectStreams() {
    if (!_parameters.isCompress || _parameters.objectStreamSize <= 0) {
      return const <COSWriterObjectStream>[];
    }

    final List<COSWriterObjectStream> streams = <COSWriterObjectStream>[];
    COSWriterObjectStream? current;
    for (var index = 0; index < _objectStreamObjects.length; index++) {
      final key = _objectStreamObjects[index];
      final base = _objectPool.getObject(key);
      if (base == null) {
        continue;
      }
      if (current == null || index % _parameters.objectStreamSize == 0) {
        current = COSWriterObjectStream(this);
        streams.add(current);
      }
      current.prepareStreamObject(key, base);
    }
    return streams;
  }

  COSBase? _addObjectToPool(COSObjectKey? key, COSBase? base) {
    COSBase? current = base;
    if (current is COSObject) {
      current = current.object;
    }
    if (current == null) {
      return null;
    }

    if (key != null && _objectPool.containsKey(key)) {
      return current;
    }
    if (key == null && _objectPool.containsObject(current)) {
      return current;
    }

    // Disallow object streams
  if ((key != null && key.generationNumber != 0) ||
    current is COSStream ||
    identical(
          current,
          _document.cosDocument.trailer.getCOSDictionary(COSName.root),
        )) {
      final actualKey = _objectPool.put(key, current);
      if (actualKey == null) {
        return current;
      }
      if (base is COSObject && actualKey != key) {
        base.key = actualKey;
      }
      _topLevelObjects.add(actualKey);
      return current;
    }

    final actualKey = _objectPool.put(key, current);
    if (actualKey == null) {
      return current;
    }
    if (base is COSObject && actualKey != key) {
      base.key = actualKey;
    }
    _objectStreamObjects.add(actualKey);
    return current;
  }

  void _addStructure(COSBase? current) {
    if (current == null) {
      return;
    }

    COSBase? base = current;
    if (current is COSStream ||
        current is COSDictionary && !current.isDirect ||
        current is COSArray && !current.isDirect) {
      base = _addObjectToPool(current.key, current);
    } else if (current is COSObject) {
      base = current.object;
      base = _addObjectToPool(current.key, current);
    }

    if (base is COSArray) {
      _addElements(base.iterator);
    } else if (base is COSDictionary) {
      _addElements(base.values.iterator);
    }
  }

  void _addElements(Iterator<COSBase> elements) {
    while (elements.moveNext()) {
      final COSBase value = elements.current;
      if ((value is COSArray || value is COSDictionary) && !_allDirectObjects.contains(value)) {
        _allDirectObjects.add(value);
        _addStructure(value);
      } else if (value is COSObject) {
        final key = value.key;
        if (key != null && _objectPool.containsKey(key)) {
          final stored = _objectPool.getObject(key);
          if (identical(stored, value.object)) {
            continue;
          }
          value.key = null;
        }
        if (!value.isNull) {
          _addStructure(value);
        }
      }
    }
  }

  static int _compareKeys(COSObjectKey a, COSObjectKey b) {
    final int objectComparison = a.objectNumber.compareTo(b.objectNumber);
    if (objectComparison != 0) {
      return objectComparison;
    }
    return a.generationNumber.compareTo(b.generationNumber);
  }
}
