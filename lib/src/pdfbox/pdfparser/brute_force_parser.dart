import 'dart:math' as math;

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object.dart';
import '../cos/cos_object_key.dart';
import '../cos/cos_stream.dart';
import 'base_parser.dart';
import 'cos_parser.dart';
import 'pdf_object_stream_parser.dart';
import 'xref_trailer_resolver.dart';

/// Brute force parser mirroring PDFBox's implementation for recovering broken PDFs.
class BruteForceParser {
  BruteForceParser(this.document, this.parser)
      : source = parser.source,
        _logger = Logger('pdfbox.BruteForceParser');

  static final List<int> _xrefTable = 'xref'.codeUnits;
  static final List<int> _xrefStream = '/XRef'.codeUnits;
  static final List<int> _objMarker = 'obj'.codeUnits;
  static final List<int> _trailerMarker = 'trailer'.codeUnits;
  static final List<int> _objStreamMarker = '/ObjStm'.codeUnits;
  static final List<int> _endObjPrefix = 'ndo'.codeUnits;
  static final List<int> _endObjSuffix = 'bj'.codeUnits;
  static final List<int> _eofMarker = '%%EOF'.codeUnits;

  static const int _minimumSearchOffset = 6;
  static const int _longMaxValue = 0x7fffffffffffffff;

  final Logger _logger;
  final COSDocument document;
  final COSParser parser;
  final RandomAccessRead source;

  final Map<COSObjectKey, int> _bfSearchCOSObjectKeyOffsets =
      <COSObjectKey, int>{};
  bool _bfSearchTriggered = false;

  bool get bfSearchTriggered => _bfSearchTriggered;

  Map<COSObjectKey, int> getBFCOSObjectOffsets() {
    if (!_bfSearchTriggered) {
      _bfSearchTriggered = true;
      _bfSearchForObjects();
    }
    return _bfSearchCOSObjectKeyOffsets;
  }

  int bfSearchForXRef(int xrefOffset) {
    final tableOffsets = _bfSearchForXRefTables();
    final streamOffsets = _bfSearchForXRefStreams();
    final nearestTable = _searchNearestValue(tableOffsets, xrefOffset);
    final nearestStream = _searchNearestValue(streamOffsets, xrefOffset);

    if (nearestTable > -1 && nearestStream > -1) {
      final diffTable = (xrefOffset - nearestTable).abs();
      final diffStream = (xrefOffset - nearestStream).abs();
      if (diffTable > diffStream) {
        streamOffsets.remove(nearestStream);
        return nearestStream;
      }
      tableOffsets.remove(nearestTable);
      return nearestTable;
    }
    if (nearestTable > -1) {
      tableOffsets.remove(nearestTable);
      return nearestTable;
    }
    if (nearestStream > -1) {
      streamOffsets.remove(nearestStream);
      return nearestStream;
    }
    return -1;
  }

  void bfSearchForObjStreams(Map<COSObjectKey, int> xrefTable) {
    final originOffset = source.position;

    final objStreamOffsets = _bfSearchForObjStreamOffsets();
    final bfOffsets = getBFCOSObjectOffsets();

    objStreamOffsets.entries
        .where((entry) => bfOffsets[entry.value] == null)
        .forEach((entry) {
      _logger.warning(
          'Skipped incomplete object stream:${entry.value} at ${entry.key}');
    });

    final offsets = objStreamOffsets.entries
        .where((entry) => bfOffsets[entry.value] != null)
        .where((entry) => entry.key == bfOffsets[entry.value])
        .map((entry) => entry.key)
        .toList();

    for (final offset in offsets) {
      source.seek(offset);
      final stmObjNumber = parser.readObjectNumber();
      parser.readGenerationNumber();
      parser.readExpectedString(_objMarker, skipSurroundingSpaces: true);

      COSStream? stream;
      try {
        final dict = parser.parseCOSDictionary(false);
        stream = parser.parseCOSStream(dict);

        final objStreamParser = PDFObjectStreamParser(stream, document);
        final objectNumbers = objStreamParser.readObjectNumbers();

        for (final entry in objectNumbers.entries) {
          final objKey = COSObjectKey(entry.key, 0);
          var existingOffset = bfOffsets[objKey];
          if (existingOffset != null && existingOffset < 0) {
            final objStmKey = COSObjectKey(existingOffset.abs(), 0);
            existingOffset = bfOffsets[objStmKey];
          }
          if (existingOffset == null || offset > existingOffset) {
            bfOffsets[objKey] = -stmObjNumber;
            xrefTable[objKey] = -stmObjNumber;
          }
        }
      } on IOException catch (exception, stackTrace) {
        _logger.fine(
          'Skipped corrupt stream: ($stmObjNumber 0 R) at offset $offset',
          exception,
          stackTrace,
        );
      }
    }
    source.seek(originOffset);
  }

  COSDictionary rebuildTrailer(Map<COSObjectKey, int> xrefTable) {
    final resolver = XrefTrailerResolver()..nextXrefObj(0, XRefType.table);
    getBFCOSObjectOffsets().forEach(resolver.setXRef);
    resolver.setStartxref(0);

    document.xrefTable
      ..clear()
      ..addAll(resolver.xrefTable ?? <COSObjectKey, int>{});

    final maxKey = document.xrefTable.keys
        .map((key) => key.objectNumber)
        .fold<int>(0, (previous, value) => math.max(previous, value));
    document.highestXRefObjectNumber = maxKey;

    final trailer = resolver.trailer ?? COSDictionary();
    document.setTrailer(trailer);
    xrefTable.addAll(resolver.xrefTable ?? <COSObjectKey, int>{});

    var searchForObjStreamsDone = false;
    if (!_bfSearchForTrailer(trailer) && !_searchForTrailerItems(trailer)) {
      bfSearchForObjStreams(xrefTable);
      searchForObjStreamsDone = true;
      _searchForTrailerItems(trailer);
    }

    if (!searchForObjStreamsDone) {
      bfSearchForObjStreams(xrefTable);
    }
    return trailer;
  }

  void _bfSearchForObjects() {
    final lastEOFMarker = _bfSearchForLastEOFMarker();
    final originOffset = source.position;

    var currentOffset = _minimumSearchOffset;
    var lastObjectId = -1;
    var lastGenId = -1;
    var lastObjOffset = -1;
    var endOfObjFound = false;

    while (currentOffset < lastEOFMarker && !parser.isEOF) {
      source.seek(currentOffset);
      final nextChar = source.read();
      currentOffset++;

      if (BaseParser.isWhitespace(nextChar) && parser.isString(_objMarker)) {
        var tempOffset = currentOffset - 2;
        source.seek(tempOffset);
        var genChar = source.peek();
        if (BaseParser.isDigit(genChar)) {
          final genId = genChar - 0x30;
          tempOffset--;
          source.seek(tempOffset);
          if (parser.isWhitespace()) {
            while (tempOffset > _minimumSearchOffset && parser.isWhitespace()) {
              tempOffset--;
              source.seek(tempOffset);
            }
            var objectIdFound = false;
            while (tempOffset > _minimumSearchOffset && parser.isDigit()) {
              tempOffset--;
              source.seek(tempOffset);
              objectIdFound = true;
            }
            if (objectIdFound) {
              source.read();
              final objectId = parser.readObjectNumber();
              if (lastObjOffset > 0) {
                _bfSearchCOSObjectKeyOffsets[
                    COSObjectKey(lastObjectId, lastGenId)] = lastObjOffset;
              }
              lastObjectId = objectId;
              lastGenId = genId;
              lastObjOffset = tempOffset + 1;
              currentOffset += _objMarker.length - 1;
              endOfObjFound = false;
            }
          }
        }
      } else if (nextChar == 0x65 && parser.isString(_endObjPrefix)) {
        currentOffset += _endObjPrefix.length;
        source.seek(currentOffset);
        if (parser.isEOF) {
          endOfObjFound = true;
        } else if (parser.isString(_endObjSuffix)) {
          currentOffset += _endObjSuffix.length;
          endOfObjFound = true;
        }
      }
    }

    if ((lastEOFMarker < _longMaxValue || endOfObjFound) && lastObjOffset > 0) {
      _bfSearchCOSObjectKeyOffsets[COSObjectKey(lastObjectId, lastGenId)] =
          lastObjOffset;
    }

    source.seek(originOffset);
  }

  int _bfSearchForLastEOFMarker() {
    var lastEOFMarker = -1;
    final originOffset = source.position;
    source.seek(_minimumSearchOffset);
    var tempMarker = _findString(_eofMarker);

    while (tempMarker != -1) {
      try {
        parser.skipSpaces();
        if (!parser.isString(_xrefTable)) {
          parser.readObjectNumber();
          parser.readGenerationNumber();
        }
      } on IOException catch (exception, stackTrace) {
        _logger.fine(
          'Ignoring error while validating EOF marker at $tempMarker',
          exception,
          stackTrace,
        );
        lastEOFMarker = tempMarker;
      }
      tempMarker = _findString(_eofMarker);
    }

    source.seek(originOffset);
    if (lastEOFMarker == -1) {
      lastEOFMarker = _longMaxValue;
    }
    return lastEOFMarker;
  }

  Map<int, COSObjectKey> _bfSearchForObjStreamOffsets() {
    final result = <int, COSObjectKey>{};
    source.seek(_minimumSearchOffset);
    final objString = ' obj'.codeUnits;
    var position = _findString(_objStreamMarker);

    while (position != -1) {
      var newOffset = -1;
      var objFound = false;
      for (var i = 1; i < 40 && !objFound; i++) {
        var currentOffset = position - (i * 10);
        if (currentOffset > 0) {
          source.seek(currentOffset);
          for (var j = 0; j < 10; j++) {
            if (parser.isString(objString)) {
              var tempOffset = currentOffset - 1;
              source.seek(tempOffset);
              if (BaseParser.isDigit(source.peek())) {
                tempOffset--;
                source.seek(tempOffset);
                if (parser.isWhitespace()) {
                  var length = 0;
                  source.seek(--tempOffset);
                  while (
                      tempOffset > _minimumSearchOffset && parser.isDigit()) {
                    source.seek(--tempOffset);
                    length++;
                  }
                  if (length > 0) {
                    source.read();
                    newOffset = source.position;
                    final objNumber = parser.readObjectNumber();
                    final genNumber = parser.readGenerationNumber();
                    result[newOffset] = COSObjectKey(objNumber, genNumber);
                  }
                }
              }
              _logger.fine('Dictionary start for object stream -> $newOffset');
              objFound = true;
              break;
            } else {
              currentOffset++;
              source.read();
            }
          }
        }
      }
      source.seek(position + _objStreamMarker.length);
      position = _findString(_objStreamMarker);
    }
    return result;
  }

  List<int> _bfSearchForXRefTables() {
    final offsets = <int>[];
    source.seek(_minimumSearchOffset);
    var offset = _findString(_xrefTable);
    while (offset != -1) {
      source.seek(offset - 1);
      if (BaseParser.isWhitespace(source.read())) {
        offsets.add(offset);
      }
      source.seek(offset + _xrefTable.length);
      offset = _findString(_xrefTable);
    }
    return offsets;
  }

  List<int> _bfSearchForXRefStreams() {
    final offsets = <int>[];
    source.seek(_minimumSearchOffset);
    final objString = ' obj'.codeUnits;
    var xrefOffset = _findString(_xrefStream);

    while (xrefOffset != -1) {
      var newOffset = -1;
      var objFound = false;
      for (var i = 1; i < 40 && !objFound; i++) {
        var currentOffset = xrefOffset - (i * 10);
        if (currentOffset > 0) {
          source.seek(currentOffset);
          for (var j = 0; j < 10; j++) {
            if (parser.isString(objString)) {
              var tempOffset = currentOffset - 1;
              source.seek(tempOffset);
              if (BaseParser.isDigit(source.peek())) {
                tempOffset--;
                source.seek(tempOffset);
                if (parser.isWhitespace()) {
                  var length = 0;
                  source.seek(--tempOffset);
                  while (
                      tempOffset > _minimumSearchOffset && parser.isDigit()) {
                    source.seek(--tempOffset);
                    length++;
                  }
                  if (length > 0) {
                    source.read();
                    newOffset = source.position;
                  }
                }
              }
              _logger.fine(
                  'Fixed reference for xref stream $xrefOffset -> $newOffset');
              objFound = true;
              break;
            } else {
              currentOffset++;
              source.read();
            }
          }
        }
      }
      if (newOffset > -1) {
        offsets.add(newOffset);
      }
      source.seek(xrefOffset + _xrefStream.length);
      xrefOffset = _findString(_xrefStream);
    }
    return offsets;
  }

  bool _bfSearchForTrailer(COSDictionary trailer) {
    final originOffset = source.position;
    source.seek(_minimumSearchOffset);
    var trailerOffset = _findString(_trailerMarker);

    while (trailerOffset != -1) {
      try {
        var rootFound = false;
        var infoFound = false;
        parser.skipSpaces();
        final trailerDict = parser.parseCOSDictionary(true);
        final rootObjBase = trailerDict.getItem(COSName.root);
        final rootObj = rootObjBase is COSObject ? rootObjBase : null;
        if (rootObj != null) {
          final rootDict = rootObj.object;
          if (rootDict is COSDictionary && _isCatalog(rootDict)) {
            rootFound = true;
          }
        }
        final infoObjBase = trailerDict.getItem(COSName.info);
        final infoObj = infoObjBase is COSObject ? infoObjBase : null;
        if (infoObj != null) {
          final infoDict = infoObj.object;
          if (infoDict is COSDictionary && _isInfo(infoDict)) {
            infoFound = true;
          }
        }
        if (rootFound && infoFound) {
          if (rootObj != null) {
            trailer[COSName.root] = rootObj;
          }
          if (infoObj != null) {
            trailer[COSName.info] = infoObj;
          }
          final encryptName = COSName.get('Encrypt');
          if (trailerDict.containsKey(encryptName)) {
            final encObjBase = trailerDict.getItem(encryptName);
            if (encObjBase is COSObject && encObjBase.object is COSDictionary) {
              trailer[encryptName] = encObjBase;
            }
          }
          if (trailerDict.containsKey(COSName.id)) {
            final idObj = trailerDict.getItem(COSName.id);
            if (idObj is COSArray) {
              trailer[COSName.id] = idObj;
            }
          }
          return true;
        }
      } on IOException catch (exception, stackTrace) {
        _logger.fine(
          'Ignoring trailer parse error at $trailerOffset',
          exception,
          stackTrace,
        );
      }
      trailerOffset = _findString(_trailerMarker);
    }

    source.seek(originOffset);
    return false;
  }

  bool _searchForTrailerItems(COSDictionary trailer) {
    COSObject? rootObject;
    COSObject? infoObject;

    for (final entry in getBFCOSObjectOffsets().entries) {
      final key = entry.key;
      final offset = entry.value;
      if (offset < 0) {
        continue;
      }
      COSObject? cosObject;
      try {
        cosObject = parser.parseIndirectObjectAt(offset, document: document);
      } on IOException catch (exception, stackTrace) {
        _logger.fine(
          'Failed to parse object $key at offset $offset during trailer recovery',
          exception,
          stackTrace,
        );
        continue;
      }
      if (cosObject == null) {
        continue;
      }
      final baseObject = cosObject.object;
      if (baseObject is! COSDictionary) {
        continue;
      }
      final dictionary = baseObject;
      if (_isCatalog(dictionary)) {
        rootObject = _compareCOSObjects(cosObject, offset, rootObject);
      } else if (_isInfo(dictionary)) {
        infoObject = _compareCOSObjects(cosObject, offset, infoObject);
      }
    }

    if (rootObject != null) {
      trailer[COSName.root] = rootObject;
    }
    if (infoObject != null) {
      trailer[COSName.info] = infoObject;
    }
    return rootObject != null;
  }

  COSObject _compareCOSObjects(
    COSObject newObject,
    int newOffset,
    COSObject? currentObject,
  ) {
    if (currentObject != null) {
      final currentKey = currentObject.key;
      final newKey = newObject.key;
      if (currentKey != null && newKey != null) {
        if (currentKey.objectNumber == newKey.objectNumber) {
          return currentKey.generationNumber < newKey.generationNumber
              ? newObject
              : currentObject;
        }
        final currentOffset = document.xrefTable[currentKey];
        if (currentOffset != null && newOffset > currentOffset) {
          return newObject;
        }
        return currentObject;
      }
      return currentObject;
    }
    return newObject;
  }

  int _searchNearestValue(List<int> values, int offset) {
    var nearest = -1;
    int? currentDifference;
    for (var i = 0; i < values.length; i++) {
      final difference = offset - values[i];
      if (currentDifference == null ||
          currentDifference.abs() > difference.abs()) {
        currentDifference = difference;
        nearest = values[i];
      }
    }
    return nearest;
  }

  bool _isInfo(COSDictionary dictionary) {
    final parent = COSName.parent;
    final aName = COSName.get('A');
    final destName = COSName.get('Dest');
    if (dictionary.containsKey(parent) ||
        dictionary.containsKey(aName) ||
        dictionary.containsKey(destName)) {
      return false;
    }
    return dictionary.containsKey(COSName.modDate) ||
        dictionary.containsKey(COSName.title) ||
        dictionary.containsKey(COSName.author) ||
        dictionary.containsKey(COSName.subject) ||
        dictionary.containsKey(COSName.keywords) ||
        dictionary.containsKey(COSName.creator) ||
        dictionary.containsKey(COSName.producer) ||
        dictionary.containsKey(COSName.creationDate);
  }

  bool _isCatalog(COSDictionary dictionary) {
    final typeName = dictionary.getCOSName(COSName.type);
    if (typeName != null && typeName.name == 'Catalog') {
      return true;
    }
    return dictionary.containsKey(COSName.get('FDF'));
  }

  int _findString(List<int> pattern) {
    var position = -1;
    final length = pattern.length;
    var counter = 0;
    var readChar = source.read();

    while (readChar != -1) {
      if (readChar == pattern[counter]) {
        if (counter == 0) {
          position = source.position - 1;
        }
        counter++;
        if (counter == length) {
          return position;
        }
      } else if (counter > 0) {
        counter = 0;
        position = -1;
        continue;
      }
      readChar = source.read();
    }
    return position;
  }
}
