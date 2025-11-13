import 'dart:collection';

import 'package:logging/logging.dart';

import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object_key.dart';

/// Collects xref/trailer information in the order they are discovered and
/// resolves the active chain once the final startxref offset is known.
class XrefTrailerResolver {
  XrefTrailerResolver() : _logger = Logger('pdfbox.XrefTrailerResolver');

  final Logger _logger;

  final Map<int, _XrefTrailerObj> _bytePosToXrefMap = <int, _XrefTrailerObj>{};

  _XrefTrailerObj? _current;
  _XrefTrailerObj? _resolved;

  COSDictionary? get firstTrailer {
    if (_bytePosToXrefMap.isEmpty) {
      return null;
    }
    final sorted = SplayTreeSet<int>.from(_bytePosToXrefMap.keys);
    return _bytePosToXrefMap[sorted.first]?.trailer;
  }

  COSDictionary? get lastTrailer {
    if (_bytePosToXrefMap.isEmpty) {
      return null;
    }
    final sorted = SplayTreeSet<int>.from(_bytePosToXrefMap.keys);
    return _bytePosToXrefMap[sorted.last]?.trailer;
  }

  int get trailerCount => _bytePosToXrefMap.length;

  void nextXrefObj(int startBytePos, XRefType type) {
    final obj = _XrefTrailerObj(type: type);
    _bytePosToXrefMap[startBytePos] = obj;
    _current = obj;
  }

  XRefType? get xrefType => _resolved?.type;

  void setXRef(COSObjectKey key, int offset) {
    final current = _current;
    if (current == null) {
      _logger.warning(
        "Cannot add XRef entry for '${key.objectNumber}' because XRef start was not signalled.",
      );
      return;
    }
    current.addXref(key, offset);
  }

  void setTrailer(COSDictionary trailer) {
    final current = _current;
    if (current == null) {
      _logger.warning('Cannot add trailer because XRef start was not signalled.');
      return;
    }
    current.trailer = trailer;
  }

  COSDictionary? get currentTrailer => _current?.trailer;

  void setStartxref(int startxrefBytePosValue) {
    if (_resolved != null) {
      _logger.warning('Method must be called only once with last startxref value.');
      return;
    }

    final resolved = _XrefTrailerObj(type: XRefType.table)
      ..trailer = COSDictionary();
    _resolved = resolved;

    var current = _bytePosToXrefMap[startxrefBytePosValue];
    final sequence = <int>[];

    if (current == null) {
      _logger.warning(
        'Did not find XRef object at specified startxref position $startxrefBytePosValue',
      );
      sequence.addAll(_bytePosToXrefMap.keys);
      sequence.sort();
    } else {
      resolved.type = current.type;
      sequence.add(startxrefBytePosValue);
      while (current?.trailer != null) {
        final trailer = current!.trailer!;
        final prevBytePos = trailer.getInt(COSName.prev, -1) ?? -1;
        if (prevBytePos == -1) {
          break;
        }
        current = _bytePosToXrefMap[prevBytePos];
        if (current == null) {
          _logger.warning(
            "Did not find XRef object pointed to by 'Prev' key at position $prevBytePos",
          );
          break;
        }
        sequence.add(prevBytePos);
        if (sequence.length >= _bytePosToXrefMap.length) {
          break;
        }
      }
      final reversed = sequence.reversed.toList();
      sequence
        ..clear()
        ..addAll(reversed);
    }

    for (final bytePos in sequence) {
      final obj = _bytePosToXrefMap[bytePos];
      if (obj == null) {
        continue;
      }
      final objTrailer = obj.trailer;
      if (objTrailer != null) {
        resolved.trailer?.addAll(objTrailer);
      }
      resolved.xrefTable.addAll(obj.xrefTable);
    }
  }

  COSDictionary? get trailer => _resolved?.trailer;

  Map<COSObjectKey, int>? get xrefTable => _resolved?.xrefTable;

  Set<int>? getContainedObjectNumbers(int objstmObjNr) {
    final resolved = _resolved;
    if (resolved == null) {
      return null;
    }
    final target = -objstmObjNr;
    final result = <int>{};
    resolved.xrefTable.forEach((key, value) {
      if (value == target) {
        result.add(key.objectNumber);
      }
    });
    return result;
  }

  void reset() {
    for (final entry in _bytePosToXrefMap.values) {
      entry.reset();
    }
    _current = null;
    _resolved = null;
  }
}

enum XRefType {
  table,
  stream,
}

class _XrefTrailerObj {
  _XrefTrailerObj({required this.type});

  COSDictionary? trailer;
  XRefType type;
  final Map<COSObjectKey, int> xrefTable = <COSObjectKey, int>{};

  void addXref(COSObjectKey key, int offset) {
    xrefTable.putIfAbsent(key, () => offset);
  }

  void reset() {
    xrefTable.clear();
    trailer = null;
  }
}
